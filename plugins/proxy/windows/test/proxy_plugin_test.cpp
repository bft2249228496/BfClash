#include <flutter/method_call.h>
#include <flutter/method_result_functions.h>
#include <flutter/standard_method_codec.h>
#include <gtest/gtest.h>

#include <windows.h>
#include <wininet.h>

#include <memory>
#include <string>
#include <variant>
#include <vector>

#include "proxy_plugin.h"

namespace proxy {
namespace test {

namespace {

using flutter::EncodableList;
using flutter::EncodableMap;
using flutter::EncodableValue;
using flutter::MethodCall;
using flutter::MethodResultFunctions;

}  // namespace

TEST(ProxyPlugin, UnknownMethodIsNotImplemented) {
  ProxyPlugin plugin;
  bool not_implemented = false;
  plugin.HandleMethodCall(
      MethodCall("unknown", std::make_unique<EncodableValue>()),
      std::make_unique<MethodResultFunctions<>>(
          nullptr, nullptr,
          [&not_implemented]() { not_implemented = true; }));

  EXPECT_TRUE(not_implemented);
}

TEST(ProxyPlugin, StopBeforeStartDoesNotChangeWindowsProxy) {
  DWORD before_size = 0;
  InternetQueryOption(nullptr, INTERNET_OPTION_PROXY, nullptr, &before_size);
  std::vector<BYTE> before(before_size);
  ASSERT_TRUE(InternetQueryOption(
      nullptr, INTERNET_OPTION_PROXY, before.data(), &before_size));
  const auto* before_info = reinterpret_cast<const INTERNET_PROXY_INFO*>(before.data());
  const DWORD access_type = before_info->dwAccessType;
  const std::wstring server = before_info->lpszProxy == nullptr ? L"" : before_info->lpszProxy;
  const std::wstring bypass = before_info->lpszProxyBypass == nullptr ? L"" : before_info->lpszProxyBypass;

  ProxyPlugin plugin;
  bool acknowledged = false;
  plugin.HandleMethodCall(
      MethodCall("StopProxy", std::make_unique<EncodableValue>()),
      std::make_unique<MethodResultFunctions<>>(
          [&acknowledged](const EncodableValue* value) {
            acknowledged = value != nullptr && std::get<bool>(*value);
          }, nullptr, nullptr));
  EXPECT_TRUE(acknowledged);

  DWORD after_size = 0;
  InternetQueryOption(nullptr, INTERNET_OPTION_PROXY, nullptr, &after_size);
  std::vector<BYTE> after(after_size);
  ASSERT_TRUE(InternetQueryOption(
      nullptr, INTERNET_OPTION_PROXY, after.data(), &after_size));
  const auto* after_info = reinterpret_cast<const INTERNET_PROXY_INFO*>(after.data());
  EXPECT_EQ(access_type, after_info->dwAccessType);
  EXPECT_EQ(server, after_info->lpszProxy == nullptr ? L"" : after_info->lpszProxy);
  EXPECT_EQ(bypass, after_info->lpszProxyBypass == nullptr ? L"" : after_info->lpszProxyBypass);
}

TEST(ProxyPlugin, StartProxyRejectsMissingArguments) {
  ProxyPlugin plugin;
  std::string error_code;
  plugin.HandleMethodCall(
      MethodCall("StartProxy", std::make_unique<EncodableValue>(EncodableMap())),
      std::make_unique<MethodResultFunctions<>>(
          nullptr,
          [&error_code](
              const std::string& code,
              const std::string& message,
              const EncodableValue* details) { error_code = code; },
          nullptr));

  EXPECT_EQ(error_code, "bad_args");
}

TEST(ProxyPlugin, StartProxyRejectsInvalidPort) {
  ProxyPlugin plugin;
  std::string error_code;
  EncodableMap arguments = {
      {EncodableValue("port"), EncodableValue(70000)},
      {EncodableValue("bypassDomain"), EncodableValue(EncodableList())}};

  plugin.HandleMethodCall(
      MethodCall(
          "StartProxy",
          std::make_unique<EncodableValue>(std::move(arguments))),
      std::make_unique<MethodResultFunctions<>>(
          nullptr,
          [&error_code](
              const std::string& code,
              const std::string& message,
              const EncodableValue* details) { error_code = code; },
          nullptr));

  EXPECT_EQ(error_code, "bad_args");
}

TEST(ProxyPlugin, StartProxyRejectsNonStringBypassDomain) {
  ProxyPlugin plugin;
  std::string error_code;
  EncodableList bypass_domain = {
      EncodableValue("localhost"),
      EncodableValue(1)};
  EncodableMap arguments = {
      {EncodableValue("port"), EncodableValue(7890)},
      {EncodableValue("bypassDomain"),
       EncodableValue(std::move(bypass_domain))}};

  plugin.HandleMethodCall(
      MethodCall(
          "StartProxy",
          std::make_unique<EncodableValue>(std::move(arguments))),
      std::make_unique<MethodResultFunctions<>>(
          nullptr,
          [&error_code](
              const std::string& code,
              const std::string& message,
              const EncodableValue* details) { error_code = code; },
          nullptr));

  EXPECT_EQ(error_code, "bad_args");
}

TEST(ProxyPlugin, RestoresTheSystemProxyOnlyWhenTheSessionReallyEnds) {
  EXPECT_TRUE(ProxyPlugin::IsSessionEnding(WM_ENDSESSION, TRUE));
  // A cancelled shutdown reports itself through the same message, and acting on
  // it would strip the proxy from a session that goes on running.
  EXPECT_FALSE(ProxyPlugin::IsSessionEnding(WM_ENDSESSION, FALSE));
  EXPECT_FALSE(ProxyPlugin::IsSessionEnding(WM_QUERYENDSESSION, TRUE));
  EXPECT_FALSE(ProxyPlugin::IsSessionEnding(WM_CLOSE, TRUE));
}

}  // namespace test
}  // namespace proxy
