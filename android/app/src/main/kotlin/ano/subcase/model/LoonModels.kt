package ano.subcase.model
data class LoonRequest(
    val url: String,
    val method: String,
    val headers: Map<String, String>,
    val body: String?,
)
data class LoonResponse(
    val status: Int = 200,
    val headers: Map<String, String> = emptyMap(),
    val body: String = "",
)
enum class SubStoreScript(
    val fileName: String,
    val tag: String,
) {
    SIMPLE("sub-store-0.min.js", "Sub-Store Simple"),
    CORE("sub-store-1.min.js", "Sub-Store Core"),
}
