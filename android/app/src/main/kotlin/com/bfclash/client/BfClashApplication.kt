package com.bfclash.client

import android.app.Application
import android.content.Context
import com.bfclash.client.common.GlobalState

class BfClashApplication : Application() {
    override fun attachBaseContext(base: Context?) {
        super.attachBaseContext(base)
        GlobalState.init(this)
    }
}
