package com.gecko.komodo

import android.app.Application

class KomodoApplication : Application() {
    override fun onCreate() {
        super.onCreate()
        LauncherIcon.ensureFromPersisted(this)
    }
}
