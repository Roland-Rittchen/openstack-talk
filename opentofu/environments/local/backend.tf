# Phase 1 bootstraps locally. Phase 2 migrates state after bucket creation.
terraform {
  backend "local" {}
}
