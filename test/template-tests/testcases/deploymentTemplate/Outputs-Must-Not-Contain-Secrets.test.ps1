param(
[Parameter(Mandatory=$true,Position=0)]
[PSObject]
$TemplateObject
)

<#
This test should flag using runtime functions that list secrets or secure parameters in the outputs

    "sample-output": {
      "type": "string",
      "value": "[listKeys(parameters('storageAccountName'),'2017-10-01').keys[0].value]"
    }
    "sample-output-secure-param": {
      "type": "string",
      "value": "[concat('connectstring stuff', parameters('adminPassword'))]"
    }

#>

#look at each output value property
foreach ($output in $TemplateObject.outputs.psobject.properties) {

    $outputText = $output.value | ConvertTo-Json # search the entire output object to cover output copy scenarios

<#    regex:
      TODO - any number of non-alphanumeric chars (comma, space, paren, etc) (this ensures it's the start of a list* function and not a UDF with the name "list")
      DONE - literal match of "list"
      DONE - any number of alpha-numerica chars followed by 0 or more whitepace
      DONE - literal match of open paren "("
#>

    if ($outputText -match "`"\s{0,}\[.*?list\w{0,}\s{0,}\(") { # TODO trying to avoid [[ doesn't work here like it does below
        Write-Error -Message "Output contains secret: $($output.Name)" -ErrorId Output.Contains.Secret -TargetObject $output
    }
}

# find all secureString and secureObject parameters
foreach ($parameterProp in $templateObject.parameters.psobject.properties) {
    $parameter = $parameterProp.Value
    $name = $parameterProp.Name
    # If the parameter is a secureString or secureObject it shouldn't be in the outputs:
    if ($parameter.Type -eq 'securestring' -or $parameter.Type -eq 'secureobject') { 
        
        foreach ($output in $TemplateObject.outputs.psobject.properties) {

            $outputText = $output.Value | ConvertTo-Json
            <#
            - begins with "[
            - any number of chars
            - 0 or more whitespace
            - parameters
            - 0 or more whitespace
            - (
            - 0 or more whitespace
            - '

            An expression could be: "[ concat ( parameters ( 'test' ), ...)]"
            #>

            if ($outputText -match "`"\s{0,}\[.*?parameters\s{0,}\(\s{0,}'$($Name)'") { 
                Write-Error -Message "Output contains $($parameterProp.Type) parameter: $($output.Name)" -ErrorId Output.Contains.SecureParameter -TargetObject $output
            }
        }        
    }
}

