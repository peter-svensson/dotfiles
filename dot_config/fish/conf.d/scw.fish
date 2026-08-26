# Completion for `scw-profile` must be registered here, not at the bottom of
# functions/scw/scw-profile.fish. Fish autoloads a function file only when the
# function it names is first called, so a `complete` line inside it does not run
# in a fresh shell — tabbing before ever calling `scw-profile` fell through to
# filename completion and offered directory names.
complete -f -c scw-profile -a '(__scw_profile_complete)'
