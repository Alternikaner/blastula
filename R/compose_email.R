#' Create the email message body
#'
#' The `compose_email()` function allows us to easily create an email message.
#' We can incorporate character vectors into the message body, the header, or
#' the footer.
#'
#' @param header,body,footer The three layout sections for an email message
#'   (ordered from top to bottom). Markdown text can be supplied to each of
#'   these by using the [md()] text helper function. Alternatively, we can
#'   supply a set of `block_*()` calls enclosed within the [blocks()] function
#'   to take advantage of precomposed HTML blocks.
#' @param title The title of the email message. This is not the subject but the
#'   HTML title text which may appear in limited circumstances.
#'
#' @examples
#' # Create a simple email message using
#' # Markdown-formatted text in the `body`
#' # and `footer` sections with the `md()`
#' # text helper function
#' email <-
#'   compose_email(
#'     body = md(
#' "
#' ## Hello!
#'
#' This is an email message that was generated by the blastula package.
#'
#' We can use **Markdown** formatting with the `md()` function.
#'
#' Cheers,
#'
#' The blastula team
#' "),
#'   footer = md(
#' "
#' sent via the [blastula](https://rich-iannone.github.io/blastula) R package
#' ")
#' )
#'
#' # The email message can always be
#' # previewed by calling the object
#' if (interactive()) email
#'
#' @return An `email_message` object.
#' @export
compose_email <- function(body = NULL,
                          header = NULL,
                          footer = NULL,
                          title = NULL) {

  # Define the title text for the email;
  # use an empty string if not supplied
  title <- title %||% ""
  title <- process_text(title)

  # Define the email body section
  if (!is.null(body)) {

    if (inherits(body, "blocks")) {

      body <- render_blocks(blocks = body, context = "body")
      html_body_text <- paste(unlist(body), collapse = "\n")

    } else {

      html_body_text <-
        simple_body_block %>%
        tidy_gsub("{html_paragraphs}", body %>% process_text(), fixed = TRUE)
    }

  } else {
    html_body_text <- ""
  }

  # Define the email footer section
  if (!is.null(footer)) {

    if (inherits(footer, "blocks")) {

      footer <- render_blocks(blocks = footer, context = "footer")
      html_footer <- paste(unlist(footer), collapse = "\n")

    } else {

      html_footer <-
        render_blocks(
          blocks =
            blocks(
              block_text(footer)),
          context = "footer"
        )[[1]]
    }

  } else {
    html_footer <- ""
  }

  # Define the email header section
  if (!is.null(header)) {

    if (inherits(header, "blocks")) {

      header <- render_blocks(blocks = header, context = "header")
      html_header <- paste(unlist(header), collapse = "\n")

    } else {

      html_header <-
        render_blocks(
          blocks =
            blocks(
              block_text(header)),
          context = "header"
        )[[1]]
    }

  } else {
    html_header <- ""
  }

  # Generate the email message body
  body <-
    bls_standard_template %>%
    gfsub("\\{([a-zA-Z_]+)\\}", function(m, name) {
      switch(name,
        title = title,
        html_header = html_header,
        html_body_text = html_body_text,
        html_footer = html_footer,
        stop("Unexpected replacement token ", name)
      )
    })

  # Add the HTML bodies (two variants) to the
  # `email_message` object
  email_message <-
    list(
      html_str = body %>% as.character(),
      html_html = body %>% htmltools::HTML(),
      attachments = list()
    )

  if (email_message$html_str %>%
      stringr::str_detect("<img cid=.*? src=\"data:image/(png|jpeg);base64,.*?\"")) {

    # Extract encoded images from body
    extracted_images <-
      email_message$html_str %>%
      stringr::str_extract_all(
        "<img cid=.*? src=\"data:image/(png|jpeg);base64,.*?\"") %>%
      unlist()

    # Obtain a vector of CIDs
    cid_names <- c()
    for (i in seq(extracted_images)) {

      cid_name <-
        extracted_images[i] %>%
        stringr::str_extract("cid=\".*?\"") %>%
        stringr::str_replace_all("(cid=\"|\")", "")

      cid_names <- c(cid_names, cid_name)
    }

    # Clean the Base64 image strings
    for (i in seq(extracted_images)) {
      extracted_images[i] <-
        gsub(
          ".{1}$", "",
          extracted_images[i] %>%
            stringr::str_replace(
              "<img cid=.*? src=\"data:image/(png|jpeg);base64,", "")
        )
    }

    # Create a list with a base64 image per list element
    extracted_images <- as.list(extracted_images)

    # Apply `cid_names` to the `extracted_images` list
    names(extracted_images) <- cid_names

    # Add the list of extracted images to the
    # `email_message` list object
    email_message <-
      c(email_message, list(images = extracted_images))

    # Replace `<img>...</img>` tags with CID values
    for (i in seq(extracted_images)) {
      email_message$html_str <-
        email_message$html_str %>%
        stringr::str_replace(
          pattern = "<img cid=.*? src=\"data:image/(png|jpeg);base64,.*?\"",
          replacement = paste0("<img src=\"cid:", cid_names[i], "\"")
        )
    }
  }

  # Apply the `email_message` and `blastula_message` classes
  attr(email_message, "class") <- c("blastula_message", "email_message")

  email_message
}

simple_body_block <-
"<tr>
<td class=\"wrapper\" style=\"font-family: sans-serif; font-size: 14px; vertical-align: top; box-sizing: border-box; padding: 20px;\">
<table border=\"0\" cellpadding=\"0\" cellspacing=\"0\" style=\"border-collapse: separate; mso-table-lspace: 0pt; mso-table-rspace: 0pt; width: 100%;\">
<tbody>
<tr>
<td style=\"font-family: Helvetica, sans-serif; font-size: 14px; vertical-align: top;\">
<p style=\"font-family: Helvetica, sans-serif; font-size: 14px; font-weight: normal; margin: 0; margin-bottom: 16px;\">{html_paragraphs}</p>
</td>
</tr>
</tbody>
</table>
</td>
</tr>"
