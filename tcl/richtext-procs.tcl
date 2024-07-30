ad_library {

    Xinha integration with the richtext widget of acs-templating.

    This script defines the following two procs:

       ::richtext-xinha::initialize_widget
       ::richtext-xinha::render_widgets

    @author Gustaf Neumann
    @creation-date 1 Jan 2016
    @cvs-id $Id$
}

namespace eval ::richtext::xinha {
    variable parameter_info

    #
    # The Xinha configuration can be tailored via the NaviServer
    # config file:
    #
    # ns_section ns/server/${server}/acs/richtext-xinha
    #        ns_param XinhaVersion   1.5.6
    #        ns_param StandardPlugins TableOperations
    #
     set parameter_info {
         package_key richtext-xinha
         parameter_name XinhaVersion
         default_value 1.5.6
     }

    set package_id [apm_package_id_from_key "richtext-xinha"]
    set ::richtext::xinha::standard_plugins [parameter::get \
                                                 -package_id $package_id \
                                                 -parameter XinhaDefaultPlugins \
                                                 -default ""]

    ad_proc initialize_widget {
        -form_id
        -text_id
        {-options {}}
    } {
        Initialize an Xinha richtext editor widget.
    } {
        ns_log debug "initialize XINHA instance with <$options>"

        # The richtext widget might be specified by "options {editor
        # xinha}" or via the package parameter "RichTextEditor" of
        # acs-templating.
        #
        # The following options can be specified in the widget spec of
        # the richtext widget:
        #
        #      editor plugins width height folder_id fs_package_id
        #
        if {[dict exists $options plugins]} {
            set plugins [dict get $options plugins]
        } else {
            set plugins $::richtext::xinha::standard_plugins
        }

        set xinha_plugins [list]
        set oacs_plugins [list]
        foreach e $plugins {
            if {$e in {OacsFs OacsAttach}} {
                lappend oacs_plugins '$e'
            } else {
                lappend xinha_plugins '$e'
            }
        }
        if {[llength $oacs_plugins] > 0} {
            lappend xinha_plugins \
                [subst {{ from: '/resources/richtext-xinha/openacs-plugins', load: \[[join $oacs_plugins ,]\] }}]
        }
        set xinha_plugins [join $xinha_plugins ,]

        set xinha_options ""
        foreach e {width height folder_id fs_package_id script_dir file_types attach_parent_id wiki_p} {
            if {[dict exists $options $e]} {
                append xinha_options "xinha_config.$e = '[dict get $options $e]';\n"
            }
        }

        # DAVEB find out if there is a key datatype in the form.
        # We look for a key element in the form and use it e.g. as the
        # possible parent_id of a potential attachment.
        if {[info exists ::af_key_name($form_id)]} {
            set key [template::element get_value $form_id $::af_key_name($form_id)]
            append xinha_options "xinha_config.key = '$key';\n"
        }

        #
        # Pass as well the actual package_id to xinha (for e.g. plugins)
        #
        append xinha_options "xinha_config.package_id = '[ad_conn package_id]';\n"

        if {[dict exists $options javascript]} {
            append xinha_options [dict get $options javascript] \n
        }

        set editor_ids '[join [list $text_id {*}$::acs_blank_master__htmlareas] "','"]'

        #
        # Add the configuration via body script
        #
        set conf [subst {
            xinha_options =
            {
                _editor_lang: "[lang::conn::language]",
                xinha_editors:  \[ $editor_ids \],
                xinha_plugins:  \[ $xinha_plugins \],
                xinha_config: function(xinha_config)
                {
                    $xinha_options
                }
            }
        }]

        #
        # Load the editor and everything necessary to the current page.
        #
        ::richtext::xinha::add_editor -conf $conf

        #
        # do we need render_widgets?
        #
        return ""
    }


    ad_proc render_widgets {} {

        Render the xinha rich-text widgets. This function is created
        at a time when all rich-text widgets of this page are already
        initialized. The function is controlled via the global
        variable ::acs_blank_master(xinha)

    } {
        #
        # In case no xinha instances are created, nothing has to be
        # done (i.e. the plain text area will be shown)
        #
        if {![info exists ::acs_blank_master(xinha)]} {
            return
        }
        #
        # Since "template::head::add_javascript -src ..." prevents
        # loading the same resource multiple times, we can perform the
        # load in the per-widget initialization and we are done here.
        #
    }

    ad_proc ::richtext::xinha::resource_info {
        {-version ""}
    } {

        Get information about available version(s) of Xinha, either
        from the local filesystem, or from CDN.

    } {
        variable parameter_info

        #
        # If no version or Xinha package are specified, use the
        # configured version.
        #
        if {$version eq ""} {
            dict with parameter_info {
                set version [::parameter::get_global_value \
                                 -package_key $package_key \
                                 -parameter $parameter_name \
                                 -default $default_value]
            }
        }

        #
        # Setup variables for access via CDN vs. local resources.
        #
        set resourceDir [acs_package_root_dir richtext-xinha/www/resources]
        set cdn //s3-us-west-1.amazonaws.com/xinha

        if {[file exists $resourceDir/$version]} {
            set prefix  /resources/richtext-xinha/$version/xinha
            set cdnHost ""
        } else {
            set prefix $cdn/xinha-$version
            set cdnHost s3-us-west-1.amazonaws.com
        }

        #
        # Return the dict with at least the required fields
        #
        lappend result \
            resourceName "Xinha $version" \
            resourceDir $resourceDir \
            cdn $cdn \
            cdnHost $cdnHost \
            prefix $prefix \
            cssFiles {} \
            jsFiles  {} \
            extraFiles {} \
            downloadURLs https://s3-us-west-1.amazonaws.com/xinha/releases/xinha-$version.zip \
            urnMap {} \
            parameterInfo $parameter_info \
            configuredVersion $version

        return $result
    }

    ad_proc ::richtext::xinha::add_editor {
        {-conf ""}
        {-version ""}
        {-order 10}
    } {

        Add the necessary JavaScript and other files to the current
        page. The naming is modeled after "add_script", "add_css",
        ... but is intended to care about everything necessary,
        including the content security policies. Similar naming
        conventions should be used for other editors as well.

        This function can be as well used from other packages, such
        e.g. from the xowiki form-fields, which provide a much higher
        customization.

    } {
        set resource_info [::richtext::xinha::resource_info -version $version]
        set version [dict $get resource_info configuredVersion]
        set prefix [dict get $resource_info prefix]

        if {[dict exists $resource_info cdnHost] && [dict get $resource_info cdnHost] ne ""} {
            security::csp::require connect-src [dict get $resource_info cdnHost]
            security::csp::require script-src  [dict get $resource_info cdnHost]
            security::csp::require style-src   [dict get $resource_info cdnHost]
            security::csp::require img-src     [dict get $resource_info cdnHost]
        }

        #
        # Add required general directives for content security policies.
        #
        security::csp::require script-src 'unsafe-eval'
        security::csp::require -force script-src 'unsafe-inline'

        template::add_body_script -src $prefix/XinhaEasy.js -script $conf
    }

    ad_proc -private ::richtext::xinha::download {
        {-version ""}
    } {

        Download the Xinha package in the specified version and put
        it into a directory structure similar to the CDN structure to
        allow installation of multiple versions. When the local
        structure is available, it will be used by initialize_widget.

        Notice, that for this automated download, the "unzip" program
        must be installed and $::acs::rootdir/packages/www must be
        writable by the web server.

    } {
        set resource_info [::richtext::xinha::resource_info -version $version]
        set version [dict get $resource_info configuredVersion]

        ::util::resources::download -resource_info $resource_info
        set resourceDir [dict get $resource_info resourceDir]

        #
        # Do we have unzip installed?
        #
        set unzip [::util::which unzip]
        if {$unzip eq ""} {
            error "can't install Xinha locally; no unzip program found on PATH"
        }

        #
        # Do we have a writable output directory under resourceDir?
        #
        if {![file isdirectory $resourceDir/$version]} {
            file mkdir $resourceDir/$version
        }
        if {![file writable $resourceDir/$version]} {
            error "directory $resourceDir/$version is not writable"
        }

        #
        # So far, everything is fine, unpack the editor package.
        #
        foreach url [dict get $resource_info downloadURLs] {
            set fn [file tail $url]
            util::unzip -overwrite \
                -source $resourceDir/$version/$fn \
                -destination $resourceDir/$version
        }
    }

}

# Local variables:
#    mode: tcl
#    tcl-indent-level: 4
#    indent-tabs-mode: nil
# End:
