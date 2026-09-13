package com.lansway.client.core

import androidx.annotation.Keep

@Keep
interface InvokeInterface {
    fun onResult(result: String?)
}