function clone_bash_template --description 'Clone Bash template to specified destination'
    # Check for exactly one argument
    if test (count $argv) -ne 1
        echo "Error: clone_bash_template requires exactly one directory path!" 1>&2
        return 1
    end

    set -l target_file $argv[1]
    set -l template_path "/home/$USER/LocalRepository/bash-script-template/script.sh"

    # Verify template exists
    if not test -f $template_path
        echo "Error: Template file not found at $template_path" 1>&2
        return 2
    end

    # Check file extension
    if string match -q "*.*" $target_file
        and not string match -q "*.sh" $target_file
        and not string match -q "*.bash" $target_file
        echo 'Error: Extension not supported. Please use ".sh" or ".bash" extension.' 1>&2
        return 3
    end
    # Extensionless is perfectly fine

    # Copy template
    if not cp $template_path $target_file
        echo "Error: Failed to copy template to $target_file" 1>&2
        return 4
    end

    # Make the file executable
    chmod +x "$target_file"

    # Get filename (without path)
    set -l name (basename $target_file)
    set -l time (date +"%F %T %Z")

    # Replace placeholders in a single pass
    sed -i \
        -e "s|#~NAME~#|$name|g" \
        -e "s|#~TIME~#|$time|g" \
        $target_file

    echo "Script generated successfully at $target_file" 1>&2
end
