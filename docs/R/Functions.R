library(htmltools)
library(distilltools)
library(stringr)
library(dplyr)

googlesheets4::gs4_deauth()

gscholar_stats <- function(url) {
  cites <- get_cites(url)
  return(paste(
    'Citations:', cites$citations, '|',
    'h-index:',   cites$hindex, '|',
    'i10-index:', cites$i10index
  ))
}

get_cites <- function(url) {
  html <- xml2::read_html(url)
  node <- rvest::html_nodes(html, xpath='//*[@id="gsc_rsb_st"]')
  cites_df <- rvest::html_table(node)[[1]]
  cites <- data.frame(t(as.data.frame(cites_df)[,2]))
  names(cites) <- c('citations', 'hindex', 'i10index')
  return(cites)
}

get_pubs <- function() {
  pubs <- googlesheets4::read_sheet("https://docs.google.com/spreadsheets/d/1xyzgW5h1rVkmtO1rduLsoNRF9vszwfFZPd72zrNmhmU",
                                    sheet = "pubs")
  pubs <- make_citations(pubs)
  pubs$details <- ifelse(is.na(pubs$details), FALSE, pubs$details)
  pubs$stub <- make_stubs(pubs)
  pubs$url_details <- file.path('research', pubs$stub, "index.html")
  return(pubs)
}

make_citations <- function(pubs) {
  pubs$citation <- unlist(lapply(split(pubs, 1:nrow(pubs)), make_citation))
  return(pubs)
}

make_citation <- function(pub) {
  if (!is.na(pub$journal)) {
    pub$journal <- paste0('_', pub$journal, '_.')
  }
  if (!is.na(pub$number)) {
    pub$number <- paste0(pub$number, '.')
  }
  if (!is.na(pub$doi)) {
    pub$doi <- make_doi(pub$doi)
  }
  pub$year <- paste0("(", pub$year, ")")
  pub$title <- paste0('"', pub$title, '"')
  pub[,which(is.na(pub))] <- ''
  paste(
    pub$author, pub$year, pub$title, pub$journal, 
    pub$number, pub$doi)
}

make_doi <- function(doi) {
  return(paste0('DOI: [', doi, '](', 'https://doi.org/', doi, ')'))
}

make_stubs <- function(pubs) {
  journal <- str_to_lower(pubs$journal)
  journal <- str_replace_all(journal, ':', '')
  journal <- str_replace_all(journal, '`', '')
  journal <- str_replace_all(journal, "'", '')
  journal <- str_replace_all(journal, "\\.", '')
  journal <- str_replace_all(journal, "&", '')
  journal <- str_replace_all(journal, ',', '')
  journal <- str_replace_all(journal, '  ', '-')
  journal <- str_replace_all(journal, ' ', '-')
  return(paste0(pubs$year, '-', journal))
}

# Functions for research page: https://jhelvy.com/research
if (FALSE) {
# make_media_list <- function() {
#  media <- gsheet::gsheet2tbl(
#    url = 'https://docs.google.com/spreadsheets/d/1xyzgW5h1rVkmtO1rduLsoNRF9vszwfFZPd72zrNmhmU/edit#gid=2088158801')
#  temp <- media %>% 
#    mutate(
#      date = format(date, format = "%b %d, %Y"), 
#      outlet = paste0("**", outlet, "**"),
#      post = paste0("- ", date, " - ", outlet, ": ", post)
#    )
#  return(paste(temp$post, collapse = "\n"))
# }

 make_pub_list <- function(pubs, category, featured = FALSE) {
   x <- pubs[which(pubs$category == category),]
   if (featured) {
     x <- x[which(x$featured),]
   } else {
     x <- x[which(!x$featured),]
   }
   pub_list <- lapply(split(x, 1:nrow(x)), make_pub)
   return(paste(unlist(pub_list), collapse = ""))
 }

make_pub_list <- function(pubs, category) {
  x <- pubs[which(pubs$category == category),]
  pub_list <- lapply(split(x, 1:nrow(x)), make_pub)
  return(paste(unlist(pub_list), collapse = ""))
}

make_pub <- function(pub) {
  index <- parent.frame()$i[] # index number from the lapply
  header <- FALSE
  if (index == 1) { header <- TRUE }
  altmetric <- NULL
  if (pub$category %in% c('peer_reviewed', 'featured')) {
    altmetric <- make_altmetric(pub)
  }
  return(paste0(
    '<div class="pub">',
    as.character(markdown_to_html(paste0(index, ') ', pub$citation))), 
    make_icons(pub, details = pub$details),
    altmetric,
    '</div>',
    make_haiku(pub, header)
  ))
}

make_icons <- function(pub, details = TRUE) {
  html <- c()
  if (details) {
    html <- c(html, as.character(icon_link_custom(
      icon = "fas fa-external-link-alt",
      text = "Details",
      url  = pub$url_details, 
      class = "icon-link-details"
    )))      
  }
  if (!is.na(pub$url_pub)) {
    html <- c(html, as.character(icon_link_custom(
      icon = "fas fa-external-link-alt",
      text = "View",
      url  = pub$url_pub
    )))
  }
  if (!is.na(pub$url_pdf)) {
    html <- c(html, as.character(icon_link_custom(
      icon = "fa fa-file-pdf",
      text = "PDF",
      url  = pub$url_pdf
    )))
  }
  if (!is.na(pub$url_repo)) {
    html <- c(html, as.character(icon_link_custom(
      icon = "fab fa-github",
      text = "Code & Data",
      url  = pub$url_repo
    )))
  }
  if (!is.na(pub$url_rg)) {
    html <- c(html, as.character(icon_link_custom(
      icon = "ai ai-researchgate",
      text = "Research Gate",
      url  = pub$url_rg
    )))
  }
  if (!is.na(pub$url_other)) {
    html <- c(html, as.character(icon_link_custom(
      icon = "fas fa-external-link-alt",
      text = pub$other_label,
      url  = pub$url_other
    )))
  }
  return(paste(html, collapse = ""))
}

make_altmetric <- function(pub) {
  return(paste0(
    '<div data-badge-type="donut" data-doi="', 
    pub$doi,
    '" data-hide-no-mentions="true" class="altmetric-embed"></div>'
  ))
}

make_haiku <- function(pub, header = FALSE) {
  html <- ""
  if (!is.na(pub$haiku1)) {
    if (header) {
      html <- as.character(aside_center(list(
        HTML("<b>Haiku Summaries</b>"), 
        br(), 
        em(
          pub$haiku1, HTML("&#8226;"), 
          pub$haiku2, HTML("&#8226;"), 
          pub$haiku3)
      )))
    } else {
      html <- as.character(aside_center(list(em(
        pub$haiku1, HTML("&#8226;"), 
        pub$haiku2, HTML("&#8226;"), 
        pub$haiku3)
      )))
    }
  }
  return(html)
}

aside <- function(text) {
  return(tag("aside", list(text)))
}

center <- function(text) {
  return(tag("center", list(text)))
}

aside_center <- function(text) {
  return(aside(center(list(text))))
}

aside_center_b <- function(text) {
  return(aside(center(list(tag("b", text)))))
}

markdown_to_html <- function(text) {
  if (is.null(text)) { return(text) }
  return(HTML(markdown::renderMarkdown(text = text)))
}
}

# These are now in {distilltools}, but I've modified this one to include 
# a custom class to be able to have more control over the CSS and an
# optional target argument

if (FALSE) {
  icon_link_custom <- function(
    icon = NULL,
    text = NULL,
    url = NULL,
    class = "icon-link",
    target = "_blank"
) {
  if (!is.null(icon)) {
    text <- make_icon_text(icon, text)
  }
  return(htmltools::a(
    href = url, text, class = class, target = target, rel = "noopener"
  ))
}

make_icon_text <- function(icon, text) {
  return(HTML(paste0(make_icon(icon), " ", text)))
}

make_icon <- function(icon) {
  return(tag("i", list(class = icon)))
}

create_footer <- function() {
  
  fill <- '#ededeb'
  height <- '14px'
  
  footer <- HTML(paste0(
    '© 2021 John Paul Helveston [',
    fontawesome::fa('creative-commons', fill = fill, height = height),
    fontawesome::fa('creative-commons-by', fill = fill, height = height),
    fontawesome::fa('creative-commons-sa', fill = fill, height = height),
    '](https://creativecommons.org/licenses/by-sa/4.0/)\n',
    br(),
    fontawesome::fa('wrench', fill = fill, height = height), ' Made with ',
    fontawesome::fa('heart', fill = fill, height = height), ', [',
    fontawesome::fa('code-branch', fill = fill, height = height),
    '](https://github.com/jhelvy), and the [',
    fontawesome::fa('r-project', fill = fill, height = height),
    '](https://cran.r-project.org/) ',
    '[distill](https://github.com/rstudio/distill) package\n',
    br(),
    last_updated(), "\n\n",
    
    '<!-- Add function to open links to external links in new tab, from: -->',
    '<!-- https://yihui.name/en/2018/09/target-blank/ -->\n\n',
    '<script src="js/external-link.js"></script>'
  ))
  
  save_raw(footer, "_footer.html")
}

last_updated <- function() {
  return(span(
    paste0(
      'Last updated on ',
      format(Sys.Date(), format="%B %d, %Y")
    ),
    style = "font-size:0.8rem;")
  )
}

save_raw <- function(text, path) {
  fileConn <- file(path)
  writeLines(text, fileConn)
  close(fileConn)
}

# For creating individual pages in the "_research" folder
make_research_pages <- function() {
  pubs <- get_pubs()
  for (i in seq_len(nrow(pubs))) {
    pub <- pubs[i,]
    if (pub$details) {
      render_research_page(pub)
    }
  }
}

make_dir <- function(path) {
  if (!dir.exists(path)) { dir.create(path) }
}

render_research_page <- function(pub) {
  make_dir(here::here('_research', pub$stub))
  rmarkdown::render(
    input = file.path('_research', 'template.Rmd'),
    output_file = file.path(pub$stub, 'index.html'),
    params = list(pub = pub)
  )
}    }
