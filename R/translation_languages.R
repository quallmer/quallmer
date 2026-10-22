# Languages are given as BCP 47 tags: an ISO 639 language code, optionally
# followed by an ISO 15924 script and an ISO 3166 region or UN M.49 area,
# such as "en", "en-GB", "zh-Hant" or "es-419". Each provider spells some of
# them differently, so a tag is normalised once and then converted to the
# provider's own code; the provenance records both.

language_tag_help <- c(
  "i" = "Use a BCP 47 language tag, such as {.val en}, {.val en-GB}, {.val pt-BR} or {.val zh-Hant}.",
  "i" = "See {.url https://www.w3.org/International/questions/qa-choosing-language-tags}; look tags up at {.url https://r12a.github.io/app-subtags/}."
)

# The tag with conventional case (language lower, script title, region
# upper), accepting underscores for hyphens. Extensions and private-use
# subtags are refused, since no provider accepts them. A three-letter ISO
# 639-3 (or 639-2/B) language code becomes its two-letter ISO 639-1 code where
# there is one, since that is what the providers expect; any other is passed
# on, so that a provider that does not support the language says so.
normalise_language_tag <- function(tag, arg) {
  if (is.null(tag)) {
    return(NULL)
  }
  pattern <- "^([A-Za-z]{2,3})(?:[-_]([A-Za-z]{4}))?(?:[-_]([A-Za-z]{2}|[0-9]{3}))?$"
  if (!rlang::is_string(tag) || !grepl(pattern, tag, perl = TRUE)) {
    cli::cli_abort(c("{.arg {arg}} is not a language tag: {.val {tag}}.", language_tag_help))
  }
  parts <- regmatches(tag, regexec(pattern, tag, perl = TRUE))[[1]]
  language <- tolower(parts[2])
  if (language %in% names(iso_639_3_to_1)) language <- iso_639_3_to_1[[language]]
  script <- if (nzchar(parts[3])) paste0(toupper(substr(parts[3], 1, 1)), tolower(substr(parts[3], 2, 4)))
  region <- if (nzchar(parts[4])) toupper(parts[4])
  paste(c(language, script, region), collapse = "-")
}

# One normalised tag per document from `to` or `from`: a single tag for every
# document, or one per document. A missing tag means the provider detects that
# document's language, which only `from` allows. `NULL` is all missing.
translation_language_vector <- function(tags, arg, n, allow_missing) {
  if (is.null(tags)) {
    tags <- NA_character_
  }
  if (is.factor(tags)) {
    tags <- as.character(tags)
  }
  if (!is.character(tags) && !(is.logical(tags) && all(is.na(tags)))) {
    cli::cli_abort(c(
      "{.arg {arg}} must be a language tag, or one tag for each text.",
      language_tag_help
    ))
  }
  if (!length(tags) %in% c(1L, n)) {
    cli::cli_abort(c(
      "{.arg {arg}} must have length 1 or one tag for each of the {n} text{?s}, not {length(tags)}."
    ))
  }
  tags <- as.character(unname(tags))
  if (anyNA(tags) && !allow_missing) {
    cli::cli_abort(c("{.arg {arg}} must not contain missing values.", language_tag_help))
  }
  normalised <- rep(NA_character_, length(tags))
  for (tag in unique(tags[!is.na(tags)])) {
    normalised[!is.na(tags) & tags == tag] <- normalise_language_tag(tag, arg)
  }
  rep_len(normalised, n)
}

# Simplified or Traditional Chinese: an explicit script decides, so that
# zh-Hans-HK is Simplified; a region supplies the usual script only when
# none is given.
chinese_script <- function(tag) {
  parts <- strsplit(tag, "-", fixed = TRUE)[[1]]
  if (parts[1] != "zh" || length(parts) == 1L) {
    return(NULL)
  }
  if ("Hant" %in% parts) return("Hant")
  if ("Hans" %in% parts) return("Hans")
  if (any(c("TW", "HK", "MO") %in% parts)) return("Hant")
  if (any(c("CN", "SG") %in% parts)) return("Hans")
  NULL
}

tag_language <- function(tag) {
  strsplit(tag, "-", fixed = TRUE)[[1]][1]
}

# The languages of each text, as the list recorded in its settings:
# `target_lang`, `source_lang` (NULL where the provider detects it) and the
# `provider_languages`. A pair shared by several texts is converted once.
translation_document_languages <- function(adapter, target, source) {
  key <- paste(target, source, sep = "\r")
  converted <- lapply(unique(key), function(k) {
    i <- match(k, key)
    source_lang <- if (!is.na(source[i])) source[i]
    list(target_lang = target[i], source_lang = source_lang,
         provider_languages = translation_provider_languages(adapter, target[i], source_lang))
  })
  converted[match(key, unique(key))]
}

# The codes sent to the provider for one pair of languages, and for Qwen-MT
# any regional variant it has no code for, to be asked for in words.
translation_provider_languages <- function(adapter, target, source) {
  switch(adapter,
    deepl = list(target = deepl_language(target, target = TRUE),
                 source = if (!is.null(source)) deepl_language(source, target = FALSE)),
    `google-translate` = list(target = google_language(target),
                              source = if (!is.null(source)) google_language(source)),
    `qwen-mt` = list(target = qwen_language(target),
                     source = if (!is.null(source)) qwen_language(source) else "auto",
                     # Qwen-MT has codes for languages, not regions
                     variant = if (target != tag_language(target) &&
                                   is.null(chinese_script(target))) target),
    list(target = target, source = source)
  )
}

# DeepL: upper case; a source is a bare language, and only DeepL's own
# target variants are accepted, so that an unknown one fails before any
# request rather than once per request.
deepl_target_variants <- c("EN-GB", "EN-US", "FR-CA", "FR-FR", "DE-DE", "DE-CH",
                           "PT-BR", "PT-PT", "ES-ES", "ES-419", "ZH-HANS", "ZH-HANT")

deepl_language <- function(tag, target) {
  language <- toupper(switch(tag_language(tag), no = "nb", fil = "tl", iw = "he", tag_language(tag)))
  if (!target || tag == tag_language(tag)) {
    return(language)
  }
  script <- chinese_script(tag)
  code <- if (!is.null(script)) paste0("ZH-", toupper(script)) else toupper(tag)
  if (!code %in% deepl_target_variants) {
    offered <- deepl_target_variants[startsWith(deepl_target_variants, paste0(language, "-"))]
    offered <- vapply(offered, normalise_language_tag, "", arg = "offered", USE.NAMES = FALSE)
    cli::cli_abort(c(
      "DeepL has no target variant {.val {tag}}.",
      "i" = if (length(offered)) "Use {.val {tolower(language)}} or one of {.val {offered}}." else "Use {.val {tolower(language)}}."
    ))
  }
  code
}

# Google's Translation LLM: BCP 47, with its own codes for written Chinese
# and for Filipino.
google_language <- function(tag) {
  script <- chinese_script(tag)
  if (!is.null(script)) {
    return(paste0("zh-", script))
  }
  if (tag_language(tag) == "tl") {
    return(sub("^tl", "fil", tag))
  }
  tag
}

# Qwen-MT: bare lower-case languages, with zh_tw for Traditional Chinese.
qwen_language <- function(tag) {
  if (identical(chinese_script(tag), "Hant")) {
    return("zh_tw")
  }
  switch(tag_language(tag), no = "nb", fil = "tl", iw = "he", tag_language(tag))
}
