# One module per area; `just <module>` lists its recipes, `just <module> <recipe>` runs one.
# The modules live in just/.

mod agents 'just/agents.just'

# List the modules and their recipes
default:
    @{{just_executable()}} --justfile {{justfile()}} --list --list-submodules
