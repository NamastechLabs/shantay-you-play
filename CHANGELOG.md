# Changelog

All notable changes to this project are documented here.
The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

## [Unreleased]

### Added

- Themed error page (`app/error.vue`) in Spanish for 403, 404 and unexpected errors (DRG-1)

### Fixed

- The public runway page answers 403 with a drag-themed message until the runway reaches voting, reveal or closed, for everyone including the jury (DRG-1)
- Looks and jury looks are no longer readable through the API by other participants during the Pasarela stage (RLS migration `20261109000000_looks_hidden_until_voting`) (DRG-1)
