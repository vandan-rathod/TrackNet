$ErrorActionPreference = 'Stop'
$docx = (Resolve-Path 'C:\Users\taksh\Desktop\CITYVISION-SIH26127\fronted\tracknet_flutter\TrackNet_Frontend_Interview_Brief.docx').Path
$pdf = 'C:\Users\taksh\Desktop\CITYVISION-SIH26127\fronted\tracknet_flutter\docx_render\TrackNet_Frontend_Interview_Brief.pdf'
$word = New-Object -ComObject Word.Application
$word.Visible = $false
$doc = $word.Documents.Open($docx, $false, $true)
$doc.ExportAsFixedFormat($pdf, 17)
$doc.Close()
$word.Quit()
Write-Output $pdf
