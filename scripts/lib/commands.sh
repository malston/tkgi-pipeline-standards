#!/usr/bin/env bash
#
# Command implementations for advanced-example.sh
# Contains the implementation of the various commands supported by the script
#

# Implementation of command1
function cmd_command1() {
    local foundation=$1
    local argument=$2
    local option="${3:-false}"

    info "Executing command1 with foundation='${foundation}' and argument='${argument}' and option='${option}'"

    if [[ "${option}" == "true" ]]; then
        info "OPTION1: Would execute command1 here"
    else
        # Actual command implementation
        success "Command1 executed successfully"
    fi
}

# Implementation of command2
function cmd_command2() {
    local foundation=$1
    local argument=$2
    local option="${3:-false}"

    info "Executing command2 with foundation='${foundation}' and argument='${argument}' and option='${option}'"

    if [[ "${option}" == "true" ]]; then
        info "OPTION1: Would execute command2 here"
    else
        # Actual command implementation
        success "Command2 executed successfully"
    fi
}

# Implementation of command3
function cmd_command3() {
    local foundation=$1
    local argument1=$2
    local argument2=$3
    local flag1=$4
    local flag2=$5
    local option="${6:-false}"

    info "Executing command3 with
        foundation='${foundation}' and
        argument1='${argument1}' and
        argument2='${argument2}' and
        flag1='${flag1}' and
        flag2='${flag2}' and
        option='${option}'"

    if [[ "${option}" == "true" ]]; then
        info "OPTION1: Would execute command3 here"
    else
        # Actual command implementation
        success "Command3 executed successfully"
    fi
}
