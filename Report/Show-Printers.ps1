Function Show-Printers {
    <#
    .SYNOPSIS
        Creates a quick refresh and gridview of printers on a server
    .DESCRIPTION
    Creates a quick refresh and gridview of printers on a server
    .EXAMPLE
        PS C:\> Show-Printers
        Shows the out-gridview of the printers on s specific server
    .INPUTS
        Inputs (if any)
    .OUTPUTS
        Full grid view of printers on a server
    .NOTES
    #>
    # Set Print Server Name
    $printServer = "printserver.SomeDC.root.local"

    function Display-Printers {
        $obj = Get-Printer -CimSession "$printServer" | Select-Object Name, PrinterStatus, JobCount, Comment, Location | Where-Object { $_.Name -notlike '*XPS*' }
        $dataGrid.items.Clear()
        $obj | ForEach-Object { $dataGrid.items.Add($_) }
        $sort = New-Object System.ComponentModel.SortDescription("Name", "Ascending")
        $dataGrid.items.SortDescriptions.add($sort)    
        $dataGrid.items.Refresh()
    }

    # GUI Code
    [void][System.Reflection.Assembly]::LoadWithPartialName('presentationframework')
    [xml]$XAML = @'
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        xmlns:d="http://schemas.microsoft.com/expression/blend/2008"
        xmlns:mc="http://schemas.openxmlformats.org/markup-compatibility/2006"
        Title="[UserLog Explorer]" Height="350" Width="450" MinHeight="350" MinWidth="400" ResizeMode="CanResizeWithGrip">
    <Grid>
        <Button Name="button" Content="[ Refresh ]" Margin="10,10,10,0" VerticalAlignment="Top" Height="25"/>
        <DataGrid Name="dataGrid" Margin="10,40,10,10" IsReadOnly="True" SelectionMode="Single" SelectionUnit="Cell">
            <DataGrid.Columns>
                <DataGridTextColumn Header="Printer" Width="125" Binding="{Binding Name}" SortDirection="Descending"/>
                <DataGridTextColumn Header="Status" Width="75" Binding="{Binding PrinterStatus}"/>
                <DataGridTextColumn Header="Jobs" Width="50"  Binding="{Binding JobCount}"/>
                <DataGridTextColumn Header="Comment" Width="125"  Binding="{Binding Comment}"/>
                <DataGridTextColumn Header="Location" Width="125"  Binding="{Binding Location}"/>
            </DataGrid.Columns>
        </DataGrid>
    </Grid>
</Window>
'@

    # XAML Launcher
    $reader = (New-Object System.Xml.XmlNodeReader $xaml) 
    try { $Form = [Windows.Markup.XamlReader]::Load( $reader ) }
    catch { Write-Host "Unable to load Windows.Markup.XamlReader. Some possible causes for this problem include: .NET Framework is missing PowerShell must be launched with PowerShell -sta, invalid XAML code was encountered."; break }
    $xaml.SelectNodes("//*[@Name]") | % { Set-Variable -Name ($_.Name) -Value $Form.FindName($_.Name) }

    $button.Add_Click( {
            Display-Printers
        })

    $Form.Add_Loaded( {
            $Form.Title = "Printer Viewer"
            Display-Printers
        })
    # Show GUI
    $Form.ShowDialog() | Out-Null
}
Show-Printers