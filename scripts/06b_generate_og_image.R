# 08_generate_og_image.R
# Gera a imagem de preview Open Graph (1200 x 630 px) para a página no GitHub Pages.
# Salva em: docs/assets/img/og-preview.png
#
# Requer o pacote magick. Se não estiver instalado, o script instala automaticamente.
# No Windows, magick depende da biblioteca ImageMagick — normalmente já incluída no
# pacote CRAN. Se houver erro, instale manualmente:
#   install.packages("magick")

rm(list = ls())
gc()

project_root <- if (basename(getwd()) == "scripts") {
  normalizePath(file.path(getwd(), ".."), winslash = "/", mustWork = TRUE)
} else {
  normalizePath(getwd(), winslash = "/", mustWork = TRUE)
}

local_library <- file.path(project_root, ".r-lib")
dir.create(local_library, recursive = TRUE, showWarnings = FALSE)
.libPaths(c(local_library, .libPaths()))
options(repos = c(CRAN = "https://cloud.r-project.org"))

if (!requireNamespace("magick", quietly = TRUE)) {
  message("Instalando pacote magick...")
  install.packages("magick", lib = local_library)
}

library(magick)

out_path  <- file.path(project_root, "docs", "assets", "img", "og-preview.png")
logo_path <- file.path(project_root, "docs", "assets", "img", "logo_geocis.png")

W <- 1200L
H <-  630L

# ── paleta ───────────────────────────────────────────────────────────────────
col_bg       <- "#0b2b45"
col_accent   <- "#174c78"
col_title    <- "#ffffff"
col_subtitle <- "#bfdbfe"
col_footer   <- "#64748b"
col_url      <- "#475569"

# ── fundo ─────────────────────────────────────────────────────────────────────
img <- image_blank(W, H, color = col_bg)

# faixa de destaque vertical à esquerda
# altura cobre a área do título (y 140 → 460)
accent_bar <- image_blank(8L, 320L, color = col_accent)
img <- image_composite(img, accent_bar, offset = "+64+140")

# ── logo GeoCiS ───────────────────────────────────────────────────────────────
if (file.exists(logo_path)) {
  logo <- image_read(logo_path) |>
    image_resize("100x100") |>
    image_background("none")
  img <- image_composite(img, logo, offset = "+64+46")
} else {
  warning("Logo nao encontrado: ", logo_path)
}

# ── título principal — duas linhas para não cortar ────────────────────────────
# Linha 1: "RESERVA DOS COMPUTADORES"
img <- image_annotate(
  img,
  text     = "RESERVA DOS COMPUTADORES",
  gravity  = "NorthWest",
  location = "+84+168",
  color    = col_title,
  size     = 58L,
  weight   = 800L,
  font     = "Arial"
)

# Linha 2: "DE PROCESSAMENTO"
img <- image_annotate(
  img,
  text     = "DE PROCESSAMENTO",
  gravity  = "NorthWest",
  location = "+84+248",
  color    = col_title,
  size     = 58L,
  weight   = 800L,
  font     = "Arial"
)

# ── subtítulo ─────────────────────────────────────────────────────────────────
img <- image_annotate(
  img,
  text     = "Sistema de agendamento das estacoes de processamento do GeoCiS",
  gravity  = "NorthWest",
  location = "+84+340",
  color    = col_subtitle,
  size     = 28L,
  font     = "Arial"
)

# ── rodapé ────────────────────────────────────────────────────────────────────
# Instituição à esquerda (texto curto para não colidir com a URL)
img <- image_annotate(
  img,
  text     = "GeoCiS  ·  ESALQ  ·  USP",
  gravity  = "SouthWest",
  location = "+84+48",
  color    = col_footer,
  size     = 24L,
  font     = "Arial"
)

# URL à direita — iniciará bem após o fim da instituição
img <- image_annotate(
  img,
  text     = "moquedace.github.io/lab-processing-scheduler",
  gravity  = "SouthEast",
  location = "+64+48",
  color    = col_url,
  size     = 22L,
  font     = "Arial"
)

# ── salvar ────────────────────────────────────────────────────────────────────
image_write(img, path = out_path, format = "png")
message("Imagem OG gerada: ", out_path)
