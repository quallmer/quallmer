# Run from the package root:
# source("dev/translation-qwen-udhr-live-check.R")
# Makes real, billed calls for six complete UDHR documents (~61,000 characters).
# Requires DASHSCOPE_API_KEY for Alibaba Model Studio's Singapore endpoint.
pkgload::load_all(".")
library(quanteda)
stopifnot(
  requireNamespace("quanteda", quietly = TRUE),
  requireNamespace("quanteda.corpora", quietly = TRUE),
  nzchar(Sys.getenv("DASHSCOPE_API_KEY"))
)

udhr_ids <- c("deu_1996", "fra", "spa", "cmn_hans", "hin", "rus")
udhr <- quanteda.corpora::data_corpus_udhr[udhr_ids]
qwen_timing <- system.time(
  qwen_translated <- qlm_translate(
    udhr,
    model = "dashscope/qwen-mt-plus",
    target_lang = "en-GB",
    context = "Universal Declaration of Human Rights.",
    params = ellmer::params(temperature = 0.1),
    # Keep successful translations and failure details for inspection.
    on_error = "continue"
  )
)
qwen_provenance <- attr(qwen_translated, "provenance")
qwen_corpus <- quanteda::corpus(qwen_translated)
print(qwen_timing)
print(qwen_provenance[c(".id", "status", ".error", "adapter", "reported_model")])
qwen_user_meta <- quanteda::meta(qwen_corpus, type = "user")
qwen_user_meta$quallmer <- NULL
stopifnot(
  identical(names(qwen_translated), udhr_ids),
  all(qwen_provenance$status == "ok"),
  all(qwen_provenance$adapter == "qwen-mt"),
  identical(qwen_provenance$source_text, unname(as.character(udhr))),
  all(nzchar(as.character(qwen_translated))),
  identical(attr(qwen_corpus, "docvars"), attr(udhr, "docvars")),
  identical(quanteda::meta(qwen_corpus, type = "system"),
            quanteda::meta(udhr, type = "system")),
  identical(qwen_user_meta, quanteda::meta(udhr, type = "user")),
  identical(
    stringi::stri_count_fixed(as.character(qwen_translated), "\n\n"),
    stringi::stri_count_fixed(as.character(udhr), "\n\n")
  )
)
qwen_tokens <- quanteda::tokens(qwen_corpus)
stopifnot(
  all(quanteda::ntoken(qwen_tokens) > 0L),
  identical(quanteda::docvars(qwen_tokens), quanteda::docvars(udhr))
)

print(qwen_translated)
cat("\nAll six complete documents passed the corpus and provenance checks.\n")
# Qwen-MT does not return detected source languages: that field remains NA.
# The original language labels are retained in quanteda::docvars(qwen_translated).
