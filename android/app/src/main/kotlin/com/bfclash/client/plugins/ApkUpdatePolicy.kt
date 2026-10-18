package com.bfclash.client.plugins

class ApkUpdateRejected(val code: String) : IllegalArgumentException(code)

object ApkUpdatePolicy {
    fun validate(currentPackage: String, currentVersion: Long, candidatePackage: String, candidateVersion: Long) {
        if (candidatePackage != currentPackage) throw ApkUpdateRejected("APK_UPDATE_PACKAGE_MISMATCH")
        if (candidateVersion <= currentVersion) throw ApkUpdateRejected("APK_UPDATE_NOT_NEWER")
    }
}
