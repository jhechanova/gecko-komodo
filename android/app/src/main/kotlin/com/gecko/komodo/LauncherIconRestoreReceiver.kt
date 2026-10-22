package com.gecko.komodo

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent

/** Puts the saved school alias back after reboot or an app update. */
class LauncherIconRestoreReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent?) {
        when (intent?.action) {
            Intent.ACTION_BOOT_COMPLETED,
            Intent.ACTION_MY_PACKAGE_REPLACED,
            -> LauncherIcon.ensureFromPersisted(context)
        }
    }
}
