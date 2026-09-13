package com.follow.clash.core

import androidx.annotation.Keep

@Keep
interface TunInterface {
    fun protect(fd: Int): Boolean
    fun resolveUid(protocol: Int, source: String, target: String): Int
    fun resolvePackage(uid: Int): String
}
