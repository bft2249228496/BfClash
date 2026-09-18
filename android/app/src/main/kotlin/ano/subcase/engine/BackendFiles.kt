package ano.subcase.engine

import android.content.Context
import java.io.File

object BackendFiles {
    const val BUNDLED_VERSION = "2.39.8"
    private val scriptNames = listOf("sub-store-0.min.js", "sub-store-1.min.js")

    fun directory(context: Context): File = File(context.filesDir, "substore/backend")

    fun versionDir(context: Context): File = File(directory(context), BUNDLED_VERSION)

    fun ensureInstalled(context: Context): File {
        val root = directory(context).apply { mkdirs() }
        copyAsset(
            context,
            "substore/backend/runner.html",
            File(root, "runner.html"),
        )
        copyAsset(
            context,
            "substore/backend/loon-bridge.js",
            File(root, "loon-bridge.js"),
        )
        val versionRoot = versionDir(context).apply { mkdirs() }
        scriptNames.forEach { name ->
            copyAsset(
                context,
                "substore/backend/$BUNDLED_VERSION/$name",
                File(versionRoot, name),
            )
        }
        check(scriptNames.all { File(versionRoot, it).isFile }) {
            "Bundled Sub-Store backend is incomplete"
        }
        return root
    }

    private fun copyAsset(context: Context, source: String, target: File) {
        if (target.isFile && target.length() > 0L) return
        target.parentFile?.mkdirs()
        val pending = File(target.parentFile, "${target.name}.pending")
        context.assets.open(source).use { input ->
            pending.outputStream().use(input::copyTo)
        }
        if (target.exists()) check(target.delete()) { "Unable to replace ${target.name}" }
        check(pending.renameTo(target)) { "Unable to install ${target.name}" }
    }
}
