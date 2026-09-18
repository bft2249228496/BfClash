package ano.subcase.engine.bridge

import android.content.Context
import android.webkit.JavascriptInterface
import androidx.annotation.Keep
interface LoonPersistentStore {
    fun read(key: String): String?
    fun write(value: String?, key: String): Boolean
}
@Keep
class PersistentStoreBridge(context: Context) : LoonPersistentStore {
    private val prefs = context.getSharedPreferences(PREFERENCES_NAME, Context.MODE_PRIVATE)
    @JavascriptInterface
    override fun read(key: String): String? = synchronized(lock) {
        prefs.getString(key, null)
    }
    @JavascriptInterface
    override fun write(value: String?, key: String): Boolean = synchronized(lock) {
        val editor = prefs.edit()
        if (value == null) editor.remove(key) else editor.putString(key, value)
        editor.commit()
    }

    companion object {
        const val PREFERENCES_NAME = "sub_store_persistent_store"
        private val lock = Any()
    }
}
