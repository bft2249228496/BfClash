package com.lansway.client

import android.app.Application
import android.content.Context
import com.lansway.client.common.GlobalState

class FlClashApplication : Application() {
    override fun attachBaseContext(base: Context?) {
        super.attachBaseContext(base)
        GlobalState.init(this)
    }
}
