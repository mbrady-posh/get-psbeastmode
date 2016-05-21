Function Get-SPList {
[CmdletBinding()]
    Param(
        [Parameter(Mandatory=$True)][string]$SiteURL,
        [Parameter(Mandatory=$True)][string]$ListName
        )

    $FullURI = "$($SiteURL)/_vti_bin/lists.asmx?WSDL"
 
    $xmlDoc = new-object System.Xml.XmlDocument            
    $query = $xmlDoc.CreateElement("Query")            
    $viewFields = $xmlDoc.CreateElement("ViewFields")            
    $queryOptions = $xmlDoc.CreateElement("QueryOptions")            
    $query.set_InnerXml("FieldRef Name='Full Name'")             
    $rowLimit = "1000"            
            
    $list = $null             
    $service = $null              
            
    Try {            
        $service = New-WebServiceProxy -Uri $FullURI  -Namespace SpWs  -UseDefaultCredential              
        }            
        catch{             
            Throw $error[0]            
            }
    If ($service -ne $null) {            
        Try {                    
            $list = $service.GetListItems($listName, "", $query, $viewFields, $rowLimit, $queryOptions, "")             
            }            
            catch{             
                Throw $error[0]           
                }            
        }

    Return $list

    }

Function Set-SPListItem {
[CmdletBinding()]
    Param(
        [Parameter(Mandatory=$True)][string]$Column,
        [Parameter(Mandatory=$True)][string]$RowId,
        [Parameter(Mandatory=$True)][string]$NewValue,
        [Parameter(Mandatory=$True)][System.Xml.XmlElement]$SPList,
        [Parameter(Mandatory=$True)][string]$SiteURL,
        [Parameter(Mandatory=$True)][string]$ListName
        )

    $FullURI = "$($SiteURL)/_vti_bin/lists.asmx?WSDL"
 
    $xmlDoc = new-object System.Xml.XmlDocument            
    $query = $xmlDoc.CreateElement("Query")            
    $viewFields = $xmlDoc.CreateElement("ViewFields")            
    $queryOptions = $xmlDoc.CreateElement("QueryOptions")            
    $query.set_InnerXml("FieldRef Name='Full Name'")             
    $rowLimit = "1000"            
            
    $list = $null             
    $service = $null              
            
    Try {            
        $service = New-WebServiceProxy -Uri $FullURI  -Namespace SpWs  -UseDefaultCredential              
        }            
        catch{             
            Throw $error[0]            
            }
       
        $ndlistview = $service.getlistandview($listname, "")            
        $strlistid = $ndlistview.childnodes.item(0).name            
        $strviewid = $ndlistview.childnodes.item(1).name            
                
        # Create an xmldocument object and construct a batch element and its attributes.             
        $xmldoc = new-object system.xml.xmldocument             
            
        # note that an empty viewname parameter causes the method to use the default view               
        $batchelement = $xmldoc.createelement("batch")            
        $batchelement.setattribute("onerror", "continue")            
        $batchelement.setattribute("listversion", "1")            
        $batchelement.setattribute("viewname", $strviewid)            
            
            
        # Specify methods for the batch post using caml. to update or delete, specify the id of the item,             
        # and to update or add, specify the value to place in the specified column            
        $id = 1            
        $xml = ""         
            
        $xml += "<method id='$($id)' cmd='Update'>" +            
                "<field name='ID'>$($rowId)</field>" +            
                "<field name='$($Column)'>$($NewValue)</field>" +            
                "</method>"            
                    
        # Set the xml content                    
        $batchelement.innerxml = $xml            
            
        $ndreturn = $null
             
        try {            
            $ndreturn = $service.updatelistitems($listname, $batchelement)             
            }            
            catch {             
                Throw $error[0]    
                }
    }