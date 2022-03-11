# -*- coding: utf-8 -*-
#
# Configuration file for the Sphinx documentation builder.
#
# This file does only contain a selection of the most common options. For a
# full list see the documentation:
# http://www.sphinx-doc.org/en/master/config

# -- Path setup --------------------------------------------------------------

# If extensions (or modules to document with autodoc) are in another directory,
# add these directories to sys.path here. If the directory is relative to the
# documentation root, use os.path.abspath to make it absolute, like shown here.
#

import subprocess
import datetime
import sphinx_rtd_theme

current_year = datetime.datetime.now().year


# -- Project information -----------------------------------------------------

project = u'Banc Lib'
copyright = u'2021 - {}, GRDF'.format(current_year)
author = u'GRDF'


# The short X.Y version
version = u''
#version = get_version()

# The full version, including alpha/beta/rc tags
release = u'1.0'
#release = version


# -- General configuration ---------------------------------------------------

# If your documentation needs a minimal Sphinx version, state it here.
#
# needs_sphinx = '1.0'

extensions = [
    'sphinx_rtd_theme',
    'sphinx.ext.intersphinx',
]

templates_path = ['_templates']

source_suffix = ['.rst', '.md']

master_doc = 'index'

language = u'en'

exclude_patterns = [u'_build', 'Thumbs.db', '.DS_Store']

pygments_style = None


# -- Options for HTML output -------------------------------------------------

html_theme = "sphinx_rtd_theme"
html_logo = "pics/logo_grdf_simplifie_94-48.png"
html_theme_options = {
     'style_nav_header_background':'#3D3D3D'
}
html_static_path = ['_static']
# html_sidebars = {}

htmlhelp_basename = 'BancLib-doc'

# -- Options for LaTeX output ------------------------------------------------

latex_elements = {
    # The paper size ('letterpaper' or 'a4paper').
    #
    # 'papersize': 'letterpaper',

    # The font size ('10pt', '11pt' or '12pt').
    #
    # 'pointsize': '10pt',

    # Additional stuff for the LaTeX preamble.
    #
    # 'preamble': '',

    # Latex figure (float) alignment
    #
    # 'figure_align': 'htbp',
}

# Grouping the document tree into LaTeX files. List of tuples
# (source start file, target name, title,
#  author, documentclass [howto, manual, or own class]).
latex_documents = [
    (master_doc, 'BancLib.tex', u'BancLib Documentation',
     u'GRDF', 'manual'),
]


# -- Options for manual page output ------------------------------------------

# One entry per manual page. List of tuples
# (source start file, name, description, authors, manual section).
man_pages = [
    (master_doc, 'BancLib', u'BancLib Documentation',
     [author], 1)
]


# -- Options for Texinfo output ----------------------------------------------

# Grouping the document tree into Texinfo files. List of tuples
# (source start file, target name, title, author,
#  dir menu entry, description, category)
texinfo_documents = [
    (master_doc, 'BancLib', u'BancLib Documentation',
     author, 'BancLib', 'One line description of project.',
     'Miscellaneous'),
]


# -- Options for Epub output -------------------------------------------------

# Bibliographic Dublin Core info.
epub_title = project

# The unique identifier of the text. This can be a ISBN number
# or the project homepage.
#
# epub_identifier = ''

# A unique identification for the text.
#
# epub_uid = ''

# A list of files that should not be packed into the epub file.
epub_exclude_files = ['search.html']


# ------------------------------------------------------------------------------
