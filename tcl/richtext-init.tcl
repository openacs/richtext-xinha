template::util::richtext::register_editor xinha

if {[apm_package_installed_p xowiki]} {
    #
    # We become the preferred richtext editor for xowiki, if none was
    # chosen so far.
    #
    set preferred_editor [::parameter::get_global_value \
                              -package_key xowiki \
                              -parameter PreferredRichtextEditor]
    if {$preferred_editor eq ""} {
        ::parameter::set_global_value \
            -package_key xowiki \
            -parameter PreferredRichtextEditor \
            -value "xinha"
    }
}

# Local variables:
#    mode: tcl
#    tcl-indent-level: 4
#    indent-tabs-mode: nil
# End:
