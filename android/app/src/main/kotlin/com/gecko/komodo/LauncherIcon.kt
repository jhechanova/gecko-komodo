package com.gecko.komodo

import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.util.Log

/**
 * Keeps one `MainActivity.{alias}` launcher alias explicitly enabled.
 *
 * School aliases are `android:enabled="false"` in the manifest. A runtime
 * [PackageManager.COMPONENT_ENABLED_STATE_DEFAULT] therefore shows Komodo again.
 * The desired alias is stored here so a later process can put the override back
 * without toggling components that are already correct.
 */
object LauncherIcon {
    private const val TAG = "LauncherIcon"
    private const val PREFS = "launcher_icon"
    private const val KEY_HAS_CHOICE = "has_choice"
    private const val KEY_ALIAS = "alias"
    private const val DEFAULT_ALIAS = "default"

    fun ensure(context: Context, alias: String?) {
        persist(context, alias)
        applyIfDrifted(context, alias)
    }

    /** Restores the last [ensure] choice. No-ops until a choice has been saved. */
    fun ensureFromPersisted(context: Context) {
        val prefs = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
        if (!prefs.getBoolean(KEY_HAS_CHOICE, false)) return
        applyIfDrifted(context, prefs.getString(KEY_ALIAS, null))
    }

    private fun persist(context: Context, alias: String?) {
        val editor = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE).edit()
        editor.putBoolean(KEY_HAS_CHOICE, true)
        val normalized = normalize(alias)
        if (normalized == null) {
            editor.remove(KEY_ALIAS)
        } else {
            editor.putString(KEY_ALIAS, normalized)
        }
        editor.commit()
    }

    private fun applyIfDrifted(context: Context, alias: String?) {
        val pm = context.packageManager
        val packageName = context.packageName
        val aliases = launcherAliases(context)
        val targetSuffix = normalize(alias) ?: DEFAULT_ALIAS
        val targetClass = "$packageName.MainActivity.$targetSuffix"
        val target = aliases.find { it.className == targetClass }
        if (target == null) {
            Log.w(TAG, "Launcher alias not found: $targetSuffix")
            return
        }

        val othersDisabled = aliases.all { component ->
            component == target || isExplicitlyDisabled(pm, component)
        }
        if (isExplicitlyEnabled(pm, target) && othersDisabled) return

        Log.i(TAG, "Restoring launcher alias $targetSuffix")
        // Enable the target before disabling the others. Never read the target
        // back in this call: the write is async and a stale read must not turn
        // the default alias on beside the school icon. MainActivity itself is
        // not an alias and is left alone.
        if (!isExplicitlyEnabled(pm, target)) {
            pm.setComponentEnabledSetting(
                target,
                PackageManager.COMPONENT_ENABLED_STATE_ENABLED,
                PackageManager.DONT_KILL_APP,
            )
        }
        for (component in aliases) {
            if (component == target) continue
            if (isExplicitlyDisabled(pm, component)) continue
            pm.setComponentEnabledSetting(
                component,
                PackageManager.COMPONENT_ENABLED_STATE_DISABLED,
                PackageManager.DONT_KILL_APP,
            )
        }
    }

    private fun launcherAliases(context: Context): List<ComponentName> {
        val pm = context.packageManager
        val packageName = context.packageName
        val prefix = "$packageName.MainActivity."
        val intent = Intent(Intent.ACTION_MAIN).apply {
            addCategory(Intent.CATEGORY_LAUNCHER)
            setPackage(packageName)
        }
        return pm.queryIntentActivities(intent, PackageManager.MATCH_DISABLED_COMPONENTS)
            .map { it.activityInfo.name }
            .filter { it.startsWith(prefix) }
            .distinct()
            .map { ComponentName(packageName, it) }
    }

    private fun normalize(alias: String?): String? {
        val trimmed = alias?.trim().orEmpty()
        if (trimmed.isEmpty() || trimmed == DEFAULT_ALIAS) return null
        return trimmed
    }

    private fun isExplicitlyEnabled(pm: PackageManager, component: ComponentName): Boolean {
        return pm.getComponentEnabledSetting(component) ==
            PackageManager.COMPONENT_ENABLED_STATE_ENABLED
    }

    private fun isExplicitlyDisabled(pm: PackageManager, component: ComponentName): Boolean {
        return pm.getComponentEnabledSetting(component) ==
            PackageManager.COMPONENT_ENABLED_STATE_DISABLED
    }
}
