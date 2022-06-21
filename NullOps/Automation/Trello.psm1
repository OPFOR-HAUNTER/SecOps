# Trello.psm1 - Trello API Powershell Module
# Author: Gualberto S. Maciel / HAUNTER
# Email: gualberto.s.maciel@gmail.com
# Github: https://github.com/OPFOR-HAUNTER

function Get-Trello {
    <#
.SYNOPSIS
    Gets JSON objects from a specified Trello board. 

.DESCRIPTION
    Gets JSON objects from a specified Trello board. Objects can be specified among four choices:
    board, list, card, and lables.

.INPUTS
    -board
        [switch] Setting this switch sets the API to request the board JSON object.

    -getLists
        [switch] Setting this switch will retrieve all list JSON objects.

     -list
        [switch] Setting this switch will retrieve a specific list's JSOn object
     -listId 
        [string] The listId value of th targeted list
     -listCards
        [switch] Setthis
     -card
     -labels
.OUTPUTS
    Outputs a JSON object and a log file (Get-Trello.log). 

.EXAMPLE
    Get the lists objects available
        Get-Trello -board -getLists

    Get cards from a specific list (default is the Incidents list)
        Get-Trello -list -listId [your listId here]

.LINK
    https://developers.trello.com/reference#introduction
#>
    [CmdletBinding(DefaultParameterSetName = 'list')]
    param ( 
        [switch] [Parameter(ParameterSetName = 'board', Position = 0)] $board, # board call mode
        [switch] [Parameter(ParameterSetName = 'board', Position = 1)] $getLists, # get all list infos
        [switch] [Parameter(ParameterSetName = 'list', Position = 0)] $list, # list call mode
        [string] [Parameter(ParameterSetName = 'list', Position = 1)] $listId = '[your listId here]', # get specific list info by id, default is Incidents listId
        [switch] [Parameter(ParameterSetName = 'list', Position = 2)] $listCards, # get all cards from a specific list
        [switch] [Parameter(ParameterSetName = 'card', Position = 0)] $card, # get a specific card from a list
        [switch] [Parameter(ParameterSetName = 'lables', Position = 0)] $labels, # get a specific card from a list
        [string] $logpath = $PSScriptRoot + '\Get-Trello.log'
    )
    
    begin {
        # set API Call values
        $userAgent = ' Trello Board Powershell Script'
        $trelloKey = Get-Content -path "$env:ScriptBase\Tokens\_Trello-key.txt"
        $trelloToken =  Get-Content -path "$env:ScriptBase\Tokens\_Trello-token.txt"


        $apiCreds = "key=$trelloKey&token=$trelloToken"
        $boardId = '57c30037e2accda98d8a9746' # ISO Active Tasks board ID
        [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

        # begin log
        Out-File -FilePath $logpath -InputObject ( "*********************************************" ) -Append
        Out-File -FilePath $logpath -Force -InputObject "Initiating API call to ISO Active Tasks Trello Board" -Append
        Out-File -FilePath $logpath -Force -InputObject ("New-Trello.ps1 Runtime " + (Get-Date -format g))  -Append
    }
    process {

        # build API call
        if ($board) {
            if($getLists){
                $apiCall = "https://api.trello.com/1/boards/$boardId/?fields=lists&lists=all&list_fields=all&$apiCreds"
                Out-File -FilePath $logpath -Force -InputObject "Getting all lists available on the board..." -Append
            }else{
                $apiCall = "https://api.trello.com/1/boards/$boardId/?$apiCreds"
                Out-File -FilePath $logpath -Force -InputObject "Getting board infos..." -Append
            }
        }
        elseif ($list -and !$listCards){
            $apiCall = "https://api.trello.com/1/lists/$listId/?fields=all&$apiCreds"
            Out-File -FilePath $logpath -Force -InputObject "Getting all cards on listId $listId..." -Append
        }
        elseif ($list -and $listCards) {
            $apiCall = "https://api.trello.com/1/lists/$listId/cards/?fields=all&$apiCreds"
            Out-File -FilePath $logpath -Force -InputObject "Getting all cards on listId $listId..." -Append
        }
        elseif ($lables) {
            $apiCall = "https://api.trello.com/1/boards/$boardId/labels?$apiCreds"
            Out-File -FilePath $logpath -Force -InputObject "Getting lables info..." -Append
        }elseif ($cards) {
            $apiCall = "https://api.trello.com/1/lists/$listId/cards/?fields=all&$apiCreds"
            Out-File -FilePath $logpath -Force -InputObject ("Getting card info..." + $apiCall) -Append
        }      
        else { 
            Out-File -FilePath $logpath -Force -InputObject "Error building the API URI. Exiting." -Append
            break 
        }
              
        # try the call       
        try {
            Out-File -FilePath $logpath -Force -InputObject "Initiating API call with URI $apiCall" -Append
            $resultsObj = Invoke-RestMethod -Uri $apiCall -UserAgent $userAgent
            Out-File -FilePath $logpath -Force -InputObject $resultsObj -Append
        }
        catch {
            $ErrorMessage = $_.Exception.Message
            $FailedItem = $_.Exception.ItemName
            Out-File -FilePath $logpath -Append -InputObject ("There was an error: " + $ErrorMessage) -Append
        }
    }
    end {
        return $resultsObj
    }
}

<#
.SYNOPSIS
    # create a new Trello object on the ISO Active Tasks Trello Board 

.DESCRIPTION
    Creates a new Trello card based on parameter values to the Trello board
.INPUTS

.OUTPUTS
    Outputs a JSON object and a log file (New-Trello.log). 

.EXAMPLE
    Get the lists objects available
        New-Trello -card -listId incidents -name 'ATP Alert: Malicious Malware detected' -desc 'blah blah blah blah' -idLabels 123456

    Get cards from a specific list (default is the Incidents list), other lists ids in _lists.txt
        Get-Trello -list -listId 5b69b61773e7c85a6c14b890

.LINK
    https://developers.trello.com/reference#introduction

.NOTES
    Author: William Maciel <william.maciel@arb.ca.gov>
    Information Security Specialist
    Security Operations Center
#>
function New-Trello {
    [CmdletBinding(DefaultParameterSetName = 'card')]
    param ( 
        [switch] [Parameter(ParameterSetName = 'card', Position = 0)] $card,
        [string] [Parameter(ParameterSetName = 'card', Position = 1)] $listId,
        [string] [Parameter(ParameterSetName = 'card', Position = 2)] $name = '',
        [string] [Parameter(ParameterSetName = 'card', Position = 3)] $desc = '',
        [string] [Parameter(ParameterSetName = 'card', Position = 4)] $pos = 'bottom',
        [string] [Parameter(ParameterSetName = 'card', Position = 5)] $idLabels = '57c3003784e677fd361e2823', # default is the IR label, can add multiple seperated by comma
        [string] $logpath = $PSScriptRoot + '\New-Trello.log'
    )
    
    begin {
        # set API Call values
        $userAgent = ' Trello Board Powershell Script'
        $trelloKey = Get-Content -path "$env:ScriptBase\Tokens\_Trello-key.txt" 
        $trelloToken =  Get-Content -path "$env:ScriptBase\Tokens\_Trello-token.txt" 
        $apiCreds = "key=$trelloKey&token=$trelloToken"
        $boardId = '57c30037e2accda98d8a9746' # ISO Active Tasks board ID
        [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

        # begin log
        Out-File -FilePath $logpath -InputObject ( "*********************************************" )  -Append
        Out-File -FilePath $logpath -Force -InputObject "Initiating API call to ISO Active Tasks Trello Board" -Append
    }
    process {
        if ($card) {
            $apiCall = "https://api.trello.com/1/cards?idList=" + [uri]::EscapeUriString($listId) + "&name=" + [uri]::EscapeUriString($name) + "&desc=" + ($desc) + "&pos=" + [uri]::EscapeUriString($pos) + "&idLabels=" + [uri]::EscapeUriString($idLabels) + "&$apiCreds"
            Out-File -FilePath $logpath -Force -InputObject "Creating new card..." -Append
        }   
        else { 
            Out-File -FilePath $logpath -Force -InputObject "Error building the API URI. Exiting." -Append
            break 
        }
        
        # try the call       
        try {
            Out-File -FilePath $logpath -Force -InputObject "Initiating API call with URI $apiCall" -Append
            $resultsObj = Invoke-RestMethod -Uri $apiCall -UserAgent $userAgent -Method Post
            Out-File -FilePath $logpath -Force -InputObject $resultsObj -Append
        }
        catch {
            $ErrorMessage = $_.Exception.Message
            $FailedItem = $_.Exception.ItemName
            Out-File -FilePath $logpath -Append -InputObject ("There was an error: " + $ErrorMessage)
        }
    }
    end {
        return $resultsObj
    }
}

function Get-TrelloListDetails {
    [CmdletBinding()]
    param (
        [string] [Parameter(ParameterSetName = 'listId', Position = 0)] $listId,
        [string] [Parameter(ParameterSetName = 'name', Position = 0)] $name,
        [switch] [Parameter(ParameterSetName = 'all', Position = 0)] $all,  
        [string] $logpath = $PSScriptRoot + '\Get-TrelloListDetails.log' 
    )
    
    begin {
        $runtime = get-date -Format g

        # begin log
        Out-File -FilePath $logpath -InputObject ( "*********************************************" ) -force  -Append
        Out-File -FilePath $logpath -Force -InputObject "Get-TrelloListDetails initiating $runtime" -Append
    }
    
    process {
        # try to get all available lists
        if($all){
            try{
                Out-File -FilePath $logpath -Append -InputObject ("Atempting API call to get all available list details...")
                $listDetailsRaw = Get-Trello -board -getLists
                $listDetails = $listDetailsRaw.lists
            }
            catch{
                $ErrorMessage = $_.Exception.Message
                $FailedItem = $_.Exception.ItemName
                Out-File -FilePath $logpath -Append -InputObject ("There was an error getting list details for all lists: " + $ErrorMessage)
                break
            }
        }
        # try to get list details for list that matches listId
        if($listId){
            try{
                Out-File -FilePath $logpath -Append -InputObject ("Atempting API call to get list details for listId $listId")
                $listDetailsRaw = Get-Trello -list -listId $listId
                $listDetails = $listDetailsRaw
            }
            catch{
                $ErrorMessage = $_.Exception.Message
                $FailedItem = $_.Exception.ItemName
                Out-File -FilePath $logpath -Append -InputObject ("There was an error getting list details for listId $listId  " + $ErrorMessage)
                break
            }
        }
        # try to find a listId for a list with a name that matches $name
        if($name){
            try{
                Out-File -FilePath $logpath -Append -InputObject ("Atempting API call to get list details for list $name")
                $listDetailsRaw = Get-Trello -board -getLists
                #$nameRegEx = '.' + $name +'.'

                # search each returned list object for a match with $name
                $listDetailsRaw.lists | ForEach-Object{
                    Out-File -FilePath $logpath -Append -InputObject ("List Name: " + $_.name)
                    if($_.name -imatch $name){
                        Out-File -FilePath $logpath -Append -InputObject ("Atempting API call to get list details for listId " + $_.id)
                        $listDetails = Get-Trello -list -listId $_.id
                        break
                    }
                }
            }
            catch{
                $ErrorMessage = $_.Exception.Message
                $FailedItem = $_.Exception.ItemName
                Out-File -FilePath $logpath -Append -InputObject ("There was an error getting list details for list $name " + $ErrorMessage)
                break
            }
        }
    }
    
    end {
        Out-File -FilePath $logpath -Append -InputObject ("Returned list details:") -force
        $listDetails | ForEach-Object{
            Out-File -FilePath $logpath -Append -InputObject ($_) -force
        }
        return $listDetails
    }
}

function Remove-Trello {
    param (
        [switch] $card, # switch to delete a card object,

        [string] $objID, # object ID to target
        [string] $logpath = $PSScriptRoot + '\Remove-Trello.log'
    )
    begin{
        # set API Call values
        $userAgent = ' Trello Board Powershell Script'
        $trelloKey = Get-Content -path "$env:ScriptBase\Tokens\_Trello-key.txt" 
        $trelloToken =  Get-Content -path "$env:ScriptBase\Tokens\_Trello-token.txt" 
        $apiCreds = "key=$trelloKey&token=$trelloToken"
        $boardId = '57c30037e2accda98d8a9746' # ISO Active Tasks board ID
        [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

        # begin log
        Out-File -FilePath $logpath -InputObject ( "*********************************************" )
        Out-File -FilePath $logpath -Force -InputObject "Initiating API call to ISO Active Tasks Trello Board" -Append
    }
    process{    
        if ($card) {
            $apiCall = "https://api.trello.com/1/cards/" + $objID + "?$apiCreds"
            Out-File -FilePath $logpath -Force -InputObject "Attempting to delete card $objID" -Append
        }   
        else { 
            Out-File -FilePath $logpath -Force -InputObject "Error building the API URI. Aborting." -Append
            break 
        }

        # try the call       
        try {
            Out-File -FilePath $logpath -Force -InputObject "Initiating API call with URI $apiCall" -Append
            $resultsObj = Invoke-RestMethod -Uri $apiCall -UserAgent $userAgent -Method Delete
            Out-File -FilePath $logpath -Force -InputObject $resultsObj -Append
        }
        catch {
            $ErrorMessage = $_.Exception.Message
            $FailedItem = $_.Exception.ItemName
            Out-File -FilePath $logpath -Append -InputObject ("There was an error: " + $ErrorMessage)
        }
    }
    end{

    }
}

function Remove-TrelloMulti {
    param (
        [string] $listId,
        [array] $exceptions,
        [string] $matchTerm
    )
    $cards = Get-Trello -list -listCards

    $exceptions = @('5ea33806c41a3d7005446c2f','5ea271250cdac5650d201175','5e94e49cc42860475f4851f5','5ea2244ce3b16c4c61403668')
    
    $cards | ForEach-Object{
    
        $cardId = $_.id 
        $isException = $false
         
        foreach($exception in $exceptions){
                if($exception -notmatch $cardId){
                    $isException = $false
                    continue
                }else{
                    $isException = $true
                    break
                }
        }
    
        if($isException -ne $true){
             write-host $_.name
             write-host $_.id 
             Remove-Trello -card -objID $cardId
        }
    }       
}