#requires -Version 5.1
<#+
.SYNOPSIS
    D&D 2024 - Resolvedor de Bandos com interface Windows Forms.
.DESCRIPTION
    Usa a tabela "Resultados de Bando" do Livro do Mestre 2024 para
    determinar acertos de muitos monstros idênticos sem rolar todos os d20.

    O programa usa grupos de 4, 5, 6, 8 e 10 criaturas, como na tabela.
    Quando sobrarem de 1 a 3 criaturas, os ataques remanescentes são rolados
    individualmente. Isso evita arredondamentos ocultos.

    O dano pode ser resolvido por dano médio, uma rolagem multiplicada ou
    rolagens individuais. O dano médio é o método recomendado pelo livro.
#>

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
Add-Type -AssemblyName Microsoft.VisualBasic

[System.Windows.Forms.Application]::EnableVisualStyles()
Set-StrictMode -Version 2.0

# -----------------------------------------------------------------------------
# TABELA OFICIAL DE RESULTADOS DE BANDO
# Cada linha representa a linha encontrada após considerar Normal, Vantagem
# ou Desvantagem. As chaves internas são os tamanhos de grupo da tabela.
# -----------------------------------------------------------------------------
$script:MobTable = @{
     1 = @{ 4 = 4; 5 = 5; 6 = 6; 8 = 8; 10 = 10 }
     2 = @{ 4 = 4; 5 = 5; 6 = 6; 8 = 8; 10 = 10 }
     3 = @{ 4 = 4; 5 = 5; 6 = 5; 8 = 7; 10 = 9  }
     4 = @{ 4 = 3; 5 = 4; 6 = 5; 8 = 7; 10 = 9  }
     5 = @{ 4 = 3; 5 = 4; 6 = 5; 8 = 6; 10 = 8  }
     6 = @{ 4 = 3; 5 = 4; 6 = 5; 8 = 6; 10 = 8  }
     7 = @{ 4 = 3; 5 = 4; 6 = 4; 8 = 6; 10 = 7  }
     8 = @{ 4 = 3; 5 = 3; 6 = 4; 8 = 5; 10 = 7  }
     9 = @{ 4 = 2; 5 = 3; 6 = 4; 8 = 5; 10 = 6  }
    10 = @{ 4 = 2; 5 = 3; 6 = 3; 8 = 4; 10 = 6  }
    11 = @{ 4 = 2; 5 = 3; 6 = 3; 8 = 4; 10 = 5  }
    12 = @{ 4 = 2; 5 = 2; 6 = 3; 8 = 4; 10 = 5  }
    13 = @{ 4 = 2; 5 = 2; 6 = 2; 8 = 3; 10 = 4  }
    14 = @{ 4 = 1; 5 = 2; 6 = 2; 8 = 3; 10 = 4  }
    15 = @{ 4 = 1; 5 = 2; 6 = 2; 8 = 2; 10 = 3  }
    16 = @{ 4 = 1; 5 = 1; 6 = 2; 8 = 2; 10 = 3  }
    17 = @{ 4 = 1; 5 = 1; 6 = 1; 8 = 2; 10 = 2  }
    18 = @{ 4 = 1; 5 = 1; 6 = 1; 8 = 1; 10 = 2  }
    19 = @{ 4 = 0; 5 = 1; 6 = 1; 8 = 1; 10 = 1  }
    20 = @{ 4 = 0; 5 = 0; 6 = 0; 8 = 0; 10 = 1  }
    21 = @{ 4 = 0; 5 = 0; 6 = 0; 8 = 0; 10 = 0  }
}

$script:ModelsPath = Join-Path -Path $PSScriptRoot -ChildPath 'Bandos.modelos.json'
$script:Models = @()
$script:IsLoadingModel = $false
$script:LastSummary = ''
$script:LastInitiative = '-'

# -----------------------------------------------------------------------------
# FUNÇÕES DE REGRA E DADOS
# -----------------------------------------------------------------------------
function Get-TableRow {
    param(
        [Parameter(Mandatory = $true)][int]$Needed,
        [Parameter(Mandatory = $true)][ValidateSet('Normal','Vantagem','Desvantagem')][string]$Mode
    )

    if ($Needed -lt 1) { $Needed = 1 }

    if ($Mode -eq 'Normal') {
        if ($Needed -gt 20) { return 20 }
        return $Needed
    }

    if ($Mode -eq 'Vantagem') {
        if ($Needed -le 4)  { return 1  }
        if ($Needed -le 6)  { return 2  }
        if ($Needed -le 8)  { return 3  }
        if ($Needed -eq 9)  { return 4  }
        if ($Needed -eq 10) { return 5  }
        if ($Needed -eq 11) { return 6  }
        if ($Needed -eq 12) { return 7  }
        if ($Needed -eq 13) { return 8  }
        if ($Needed -eq 14) { return 9  }
        if ($Needed -eq 15) { return 11 }
        if ($Needed -eq 16) { return 12 }
        if ($Needed -eq 17) { return 14 }
        if ($Needed -eq 18) { return 15 }
        if ($Needed -eq 19) { return 17 }
        return 19
    }

    # Desvantagem
    if ($Needed -le 1)  { return 1  }
    if ($Needed -eq 2)  { return 3  }
    if ($Needed -eq 3)  { return 5  }
    if ($Needed -eq 4)  { return 7  }
    if ($Needed -eq 5)  { return 8  }
    if ($Needed -eq 6)  { return 10 }
    if ($Needed -eq 7)  { return 11 }
    if ($Needed -eq 8)  { return 13 }
    if ($Needed -eq 9)  { return 14 }
    if ($Needed -eq 10) { return 15 }
    if ($Needed -eq 11) { return 16 }
    if ($Needed -eq 12) { return 17 }
    if ($Needed -eq 13) { return 18 }
    if ($Needed -le 15) { return 19 }
    if ($Needed -le 17) { return 20 }
    return 21
}

function Get-GroupDecomposition {
    param([Parameter(Mandatory = $true)][int]$Quantity)

    $sizes = @(10, 8, 6, 5, 4)
    $dp = @{}
    $dp[0] = @()

    for ($i = 1; $i -le $Quantity; $i++) {
        $best = $null
        foreach ($size in $sizes) {
            $previous = $i - $size
            if ($previous -ge 0 -and $dp.ContainsKey($previous)) {
                $candidate = @($dp[$previous]) + $size
                if ($null -eq $best -or $candidate.Count -lt $best.Count) {
                    $best = $candidate
                }
                elseif ($candidate.Count -eq $best.Count) {
                    $candidateMax = ($candidate | Measure-Object -Maximum).Maximum
                    $bestMax = ($best | Measure-Object -Maximum).Maximum
                    if ($candidateMax -gt $bestMax) { $best = $candidate }
                }
            }
        }
        if ($null -ne $best) { $dp[$i] = $best }
    }

    for ($covered = $Quantity; $covered -ge 0; $covered--) {
        if ($dp.ContainsKey($covered)) {
            $groups = @($dp[$covered] | Sort-Object -Descending)
            return [PSCustomObject]@{
                Groups    = $groups
                Covered   = $covered
                Remainder = $Quantity - $covered
            }
        }
    }

    return [PSCustomObject]@{ Groups = @(); Covered = 0; Remainder = $Quantity }
}

function Roll-D20Attack {
    param(
        [int]$Bonus,
        [int]$TargetAC,
        [ValidateSet('Normal','Vantagem','Desvantagem')][string]$Mode
    )

    $roll1 = Get-Random -Minimum 1 -Maximum 21
    $rolls = @($roll1)
    $chosen = $roll1

    if ($Mode -ne 'Normal') {
        $roll2 = Get-Random -Minimum 1 -Maximum 21
        $rolls += $roll2
        if ($Mode -eq 'Vantagem') {
            $chosen = [Math]::Max($roll1, $roll2)
        }
        else {
            $chosen = [Math]::Min($roll1, $roll2)
        }
    }

    $isNatural20 = ($chosen -eq 20)
    $isNatural1 = ($chosen -eq 1)
    $success = $false

    if ($isNatural20) {
        $success = $true
    }
    elseif (-not $isNatural1 -and ($chosen + $Bonus) -ge $TargetAC) {
        $success = $true
    }

    return [PSCustomObject]@{
        Rolls       = $rolls
        Chosen      = $chosen
        Total       = $chosen + $Bonus
        Success     = $success
        IsNatural20 = $isNatural20
        IsNatural1  = $isNatural1
    }
}

function Roll-Damage {
    param(
        [int]$DiceCount,
        [int]$Faces,
        [int]$Modifier,
        [bool]$Critical = $false
    )

    $actualDice = $DiceCount
    if ($Critical) { $actualDice = $DiceCount * 2 }

    $rolls = @()
    $sum = 0
    for ($i = 1; $i -le $actualDice; $i++) {
        $roll = Get-Random -Minimum 1 -Maximum ($Faces + 1)
        $rolls += $roll
        $sum += $roll
    }

    $total = $sum + $Modifier
    if ($total -lt 0) { $total = 0 }

    return [PSCustomObject]@{
        Rolls = $rolls
        Total = $total
    }
}

function Get-AverageDamage {
    param(
        [int]$DiceCount,
        [int]$Faces,
        [int]$Modifier,
        [bool]$Critical = $false
    )

    $actualDice = $DiceCount
    if ($Critical) { $actualDice = $DiceCount * 2 }
    $average = [Math]::Floor(($actualDice * (($Faces + 1) / 2.0)) + $Modifier)
    if ($average -lt 0) { $average = 0 }
    return [int]$average
}

function Format-DamageExpression {
    param([int]$DiceCount, [int]$Faces, [int]$Modifier)

    if ($DiceCount -le 0) { return [string]$Modifier }
    $text = '{0}d{1}' -f $DiceCount, $Faces
    if ($Modifier -gt 0) { $text += '+' + $Modifier }
    elseif ($Modifier -lt 0) { $text += [string]$Modifier }
    return $text
}

function Get-GroupSummaryText {
    param([int[]]$Groups, [int]$Row)

    if ($Groups.Count -eq 0) { return 'Nenhum grupo da tabela.' }

    $parts = @()
    foreach ($size in @(10,8,6,5,4)) {
        $count = @($Groups | Where-Object { $_ -eq $size }).Count
        if ($count -gt 0) {
            $hits = [int]$script:MobTable[$Row][$size]
            if ($count -eq 1) {
                $parts += ('1 grupo de {0}: {1}/{0}' -f $size, $hits)
            }
            else {
                $parts += ('{0} grupos de {1}: {2}/{1} em cada' -f $count, $size, $hits)
            }
        }
    }
    return ($parts -join '; ')
}

function Resolve-Damage {
    param(
        [int]$TotalHits,
        [int]$CriticalHits,
        [int]$DiceCount,
        [int]$Faces,
        [int]$Modifier,
        [ValidateSet('Médio','UmaRolagem','Individual')][string]$Method
    )

    if ($TotalHits -le 0) {
        return [PSCustomObject]@{ Total = 0; Details = 'Nenhum dano: nenhum ataque acertou.' }
    }

    $normalHits = $TotalHits - $CriticalHits
    $details = New-Object System.Collections.Generic.List[string]
    $totalDamage = 0

    if ($Method -eq 'Médio') {
        $normalAverage = Get-AverageDamage -DiceCount $DiceCount -Faces $Faces -Modifier $Modifier
        $criticalAverage = Get-AverageDamage -DiceCount $DiceCount -Faces $Faces -Modifier $Modifier -Critical $true
        $totalDamage = ($normalHits * $normalAverage) + ($CriticalHits * $criticalAverage)
        $details.Add(('Dano médio normal: {0} por acerto.' -f $normalAverage))
        if ($CriticalHits -gt 0) {
            $details.Add(('Dano médio crítico: {0} por crítico.' -f $criticalAverage))
        }
    }
    elseif ($Method -eq 'UmaRolagem') {
        if ($normalHits -gt 0) {
            $rolled = Roll-Damage -DiceCount $DiceCount -Faces $Faces -Modifier $Modifier
            $subtotal = $rolled.Total * $normalHits
            $totalDamage += $subtotal
            $rollText = if ($rolled.Rolls.Count -gt 0) { $rolled.Rolls -join ', ' } else { 'sem dados' }
            $details.Add(('Rolagem normal [{0}] + modificador = {1}; x {2} acertos = {3}.' -f $rollText, $rolled.Total, $normalHits, $subtotal))
        }
        if ($CriticalHits -gt 0) {
            $rolledCrit = Roll-Damage -DiceCount $DiceCount -Faces $Faces -Modifier $Modifier -Critical $true
            $critSubtotal = $rolledCrit.Total * $CriticalHits
            $totalDamage += $critSubtotal
            $critRollText = if ($rolledCrit.Rolls.Count -gt 0) { $rolledCrit.Rolls -join ', ' } else { 'sem dados' }
            $details.Add(('Rolagem crítica [{0}] + modificador = {1}; x {2} críticos = {3}.' -f $critRollText, $rolledCrit.Total, $CriticalHits, $critSubtotal))
        }
    }
    else {
        $shown = 0
        for ($i = 1; $i -le $normalHits; $i++) {
            $rolled = Roll-Damage -DiceCount $DiceCount -Faces $Faces -Modifier $Modifier
            $totalDamage += $rolled.Total
            if ($shown -lt 30) {
                $rollText = if ($rolled.Rolls.Count -gt 0) { $rolled.Rolls -join ', ' } else { 'sem dados' }
                $details.Add(('Acerto {0}: [{1}] + modificador = {2}.' -f $i, $rollText, $rolled.Total))
                $shown++
            }
        }
        for ($i = 1; $i -le $CriticalHits; $i++) {
            $rolledCrit = Roll-Damage -DiceCount $DiceCount -Faces $Faces -Modifier $Modifier -Critical $true
            $totalDamage += $rolledCrit.Total
            if ($shown -lt 30) {
                $rollText = if ($rolledCrit.Rolls.Count -gt 0) { $rolledCrit.Rolls -join ', ' } else { 'sem dados' }
                $details.Add(('Crítico {0}: [{1}] + modificador = {2}.' -f $i, $rollText, $rolledCrit.Total))
                $shown++
            }
        }
        if (($normalHits + $CriticalHits) -gt 30) {
            $details.Add(('Detalhes limitados aos 30 primeiros resultados; {0} acertos foram calculados.' -f $TotalHits))
        }
    }

    return [PSCustomObject]@{ Total = [int]$totalDamage; Details = ($details -join [Environment]::NewLine) }
}

# -----------------------------------------------------------------------------
# FUNÇÕES DE MODELOS
# -----------------------------------------------------------------------------
function Load-Models {
    $script:Models = @()
    if (Test-Path -LiteralPath $script:ModelsPath) {
        try {
            $raw = Get-Content -LiteralPath $script:ModelsPath -Raw -ErrorAction Stop
            if (-not [string]::IsNullOrWhiteSpace($raw)) {
                $script:Models = @(ConvertFrom-Json -InputObject $raw -ErrorAction Stop)
            }
        }
        catch {
            [System.Windows.Forms.MessageBox]::Show(
                'Não foi possível ler Bandos.modelos.json. O programa continuará sem modelos salvos.' + [Environment]::NewLine + $_.Exception.Message,
                'Aviso',
                [System.Windows.Forms.MessageBoxButtons]::OK,
                [System.Windows.Forms.MessageBoxIcon]::Warning
            ) | Out-Null
        }
    }
}

function Save-ModelsFile {
    try {
        $json = @($script:Models) | ConvertTo-Json -Depth 5
        Set-Content -LiteralPath $script:ModelsPath -Value $json -Encoding UTF8 -ErrorAction Stop
        return $true
    }
    catch {
        [System.Windows.Forms.MessageBox]::Show(
            'Não foi possível salvar os modelos.' + [Environment]::NewLine + $_.Exception.Message,
            'Erro',
            [System.Windows.Forms.MessageBoxButtons]::OK,
            [System.Windows.Forms.MessageBoxIcon]::Error
        ) | Out-Null
        return $false
    }
}

# -----------------------------------------------------------------------------
# INTERFACE
# -----------------------------------------------------------------------------
$colorBackground = [System.Drawing.Color]::FromArgb(28, 31, 36)
$colorPanel = [System.Drawing.Color]::FromArgb(40, 44, 52)
$colorPanelLight = [System.Drawing.Color]::FromArgb(50, 55, 64)
$colorGold = [System.Drawing.Color]::FromArgb(218, 176, 86)
$colorText = [System.Drawing.Color]::FromArgb(238, 238, 238)
$colorMuted = [System.Drawing.Color]::FromArgb(176, 181, 190)
$colorGreen = [System.Drawing.Color]::FromArgb(112, 194, 133)
$colorRed = [System.Drawing.Color]::FromArgb(224, 110, 110)

$form = New-Object System.Windows.Forms.Form
$form.Text = 'D&D 2024 - Resolvedor de Bandos'
$form.StartPosition = 'CenterScreen'
$form.ClientSize = New-Object System.Drawing.Size(1040, 750)
$form.MinimumSize = New-Object System.Drawing.Size(1056, 789)
$form.BackColor = $colorBackground
$form.ForeColor = $colorText
$form.Font = New-Object System.Drawing.Font('Segoe UI', 9.5)
$form.AutoScaleMode = [System.Windows.Forms.AutoScaleMode]::Dpi

$toolTip = New-Object System.Windows.Forms.ToolTip
$toolTip.AutoPopDelay = 12000
$toolTip.InitialDelay = 400
$toolTip.ReshowDelay = 100

function New-Label {
    param([string]$Text, [int]$X, [int]$Y, [int]$Width = 160, [int]$Height = 24, [float]$Size = 9.5, [bool]$Bold = $false)
    $label = New-Object System.Windows.Forms.Label
    $label.Text = $Text
    $label.Location = New-Object System.Drawing.Point($X, $Y)
    $label.Size = New-Object System.Drawing.Size($Width, $Height)
    $style = if ($Bold) { [System.Drawing.FontStyle]::Bold } else { [System.Drawing.FontStyle]::Regular }
    $label.Font = New-Object System.Drawing.Font('Segoe UI', $Size, $style)
    $label.ForeColor = $colorText
    return $label
}

function New-Numeric {
    param([int]$X, [int]$Y, [int]$Width, [decimal]$Minimum, [decimal]$Maximum, [decimal]$Value, [decimal]$Increment = 1)
    $control = New-Object System.Windows.Forms.NumericUpDown
    $control.Location = New-Object System.Drawing.Point($X, $Y)
    $control.Size = New-Object System.Drawing.Size($Width, 27)
    $control.Minimum = $Minimum
    $control.Maximum = $Maximum
    $control.Value = $Value
    $control.Increment = $Increment
    $control.TextAlign = [System.Windows.Forms.HorizontalAlignment]::Center
    $control.BackColor = [System.Drawing.Color]::White
    $control.ForeColor = [System.Drawing.Color]::Black
    return $control
}

function New-Button {
    param([string]$Text, [int]$X, [int]$Y, [int]$Width, [int]$Height = 32, [System.Drawing.Color]$BackColor = $colorPanelLight)
    $button = New-Object System.Windows.Forms.Button
    $button.Text = $Text
    $button.Location = New-Object System.Drawing.Point($X, $Y)
    $button.Size = New-Object System.Drawing.Size($Width, $Height)
    $button.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
    $button.FlatAppearance.BorderSize = 1
    $button.FlatAppearance.BorderColor = $colorGold
    $button.BackColor = $BackColor
    $button.ForeColor = $colorText
    $button.Cursor = [System.Windows.Forms.Cursors]::Hand
    return $button
}

function New-GroupBox {
    param([string]$Text, [int]$X, [int]$Y, [int]$Width, [int]$Height)
    $group = New-Object System.Windows.Forms.GroupBox
    $group.Text = $Text
    $group.Location = New-Object System.Drawing.Point($X, $Y)
    $group.Size = New-Object System.Drawing.Size($Width, $Height)
    $group.ForeColor = $colorGold
    $group.BackColor = $colorPanel
    return $group
}

# Título
$title = New-Label -Text 'RESOLVEDOR DE BANDOS' -X 20 -Y 10 -Width 550 -Height 35 -Size 18 -Bold $true
$title.ForeColor = $colorGold
$form.Controls.Add($title)
$subtitle = New-Label -Text 'D&D 2024 • tabela de resultados médios • operação por mouse' -X 22 -Y 43 -Width 600 -Height 22 -Size 9
$subtitle.ForeColor = $colorMuted
$form.Controls.Add($subtitle)

# ----- Modelos e referência
$grpModel = New-GroupBox -Text 'Monstro e modelos' -X 20 -Y 72 -Width 440 -Height 134
$form.Controls.Add($grpModel)

$grpModel.Controls.Add((New-Label -Text 'Nome:' -X 14 -Y 26 -Width 70))
$txtMonsterName = New-Object System.Windows.Forms.TextBox
$txtMonsterName.Location = New-Object System.Drawing.Point(78, 24)
$txtMonsterName.Size = New-Object System.Drawing.Size(210, 27)
$txtMonsterName.Text = 'Monstro'
$grpModel.Controls.Add($txtMonsterName)

$grpModel.Controls.Add((New-Label -Text 'Modelo:' -X 14 -Y 61 -Width 70))
$cmbModels = New-Object System.Windows.Forms.ComboBox
$cmbModels.Location = New-Object System.Drawing.Point(78, 59)
$cmbModels.Size = New-Object System.Drawing.Size(210, 28)
$cmbModels.DropDownStyle = [System.Windows.Forms.ComboBoxStyle]::DropDownList
$grpModel.Controls.Add($cmbModels)

$btnSaveModel = New-Button -Text 'Salvar' -X 300 -Y 23 -Width 122 -Height 29
$grpModel.Controls.Add($btnSaveModel)
$btnDeleteModel = New-Button -Text 'Excluir' -X 300 -Y 58 -Width 122 -Height 29
$grpModel.Controls.Add($btnDeleteModel)

$grpModel.Controls.Add((New-Label -Text 'CA do monstro:' -X 14 -Y 98 -Width 110))
$numMonsterAC = New-Numeric -X 126 -Y 95 -Width 64 -Minimum 1 -Maximum 40 -Value 15
$grpModel.Controls.Add($numMonsterAC)
$grpModel.Controls.Add((New-Label -Text 'PV por criatura:' -X 205 -Y 98 -Width 112))
$numMonsterHP = New-Numeric -X 320 -Y 95 -Width 66 -Minimum 1 -Maximum 999 -Value 7
$grpModel.Controls.Add($numMonsterHP)

# ----- Dados do ataque
$grpAttack = New-GroupBox -Text 'Ataque do bando' -X 20 -Y 216 -Width 440 -Height 247
$form.Controls.Add($grpAttack)

$grpAttack.Controls.Add((New-Label -Text 'Quantidade:' -X 14 -Y 31 -Width 100))
$numQuantity = New-Numeric -X 119 -Y 28 -Width 82 -Minimum 1 -Maximum 500 -Value 10
$grpAttack.Controls.Add($numQuantity)
$btnQMinus5 = New-Button -Text '-5' -X 211 -Y 27 -Width 45 -Height 29
$btnQMinus1 = New-Button -Text '-1' -X 260 -Y 27 -Width 45 -Height 29
$btnQPlus1 = New-Button -Text '+1' -X 309 -Y 27 -Width 45 -Height 29
$btnQPlus5 = New-Button -Text '+5' -X 358 -Y 27 -Width 45 -Height 29
$grpAttack.Controls.AddRange(@($btnQMinus5,$btnQMinus1,$btnQPlus1,$btnQPlus5))

$grpAttack.Controls.Add((New-Label -Text 'CA do alvo:' -X 14 -Y 72 -Width 100))
$numTargetAC = New-Numeric -X 119 -Y 69 -Width 82 -Minimum 1 -Maximum 50 -Value 18
$grpAttack.Controls.Add($numTargetAC)
$toolTip.SetToolTip($numTargetAC, 'Classe de Armadura da criatura que receberá os ataques.')

$grpAttack.Controls.Add((New-Label -Text 'Bônus de ataque:' -X 220 -Y 72 -Width 120))
$numAttackBonus = New-Numeric -X 343 -Y 69 -Width 60 -Minimum -10 -Maximum 30 -Value 4
$grpAttack.Controls.Add($numAttackBonus)

$grpAttack.Controls.Add((New-Label -Text 'Condição:' -X 14 -Y 113 -Width 100))
$cmbMode = New-Object System.Windows.Forms.ComboBox
$cmbMode.Location = New-Object System.Drawing.Point(119, 110)
$cmbMode.Size = New-Object System.Drawing.Size(150, 28)
$cmbMode.DropDownStyle = [System.Windows.Forms.ComboBoxStyle]::DropDownList
[void]$cmbMode.Items.AddRange(@('Normal','Vantagem','Desvantagem'))
$cmbMode.SelectedIndex = 0
$grpAttack.Controls.Add($cmbMode)

$lblNeededPreview = New-Label -Text 'Jogada necessária: 14' -X 280 -Y 113 -Width 145 -Height 24 -Size 9 -Bold $true
$lblNeededPreview.ForeColor = $colorGreen
$grpAttack.Controls.Add($lblNeededPreview)

$grpAttack.Controls.Add((New-Label -Text 'Bônus de iniciativa:' -X 14 -Y 156 -Width 145))
$numInitiativeBonus = New-Numeric -X 161 -Y 153 -Width 65 -Minimum -10 -Maximum 30 -Value 2
$grpAttack.Controls.Add($numInitiativeBonus)
$btnInitiative = New-Button -Text 'Rolar iniciativa' -X 240 -Y 151 -Width 163 -Height 31
$grpAttack.Controls.Add($btnInitiative)

$lblInitiative = New-Label -Text 'Iniciativa: -' -X 14 -Y 199 -Width 389 -Height 30 -Size 12 -Bold $true
$lblInitiative.ForeColor = $colorGold
$grpAttack.Controls.Add($lblInitiative)

# ----- Dano
$grpDamage = New-GroupBox -Text 'Dano por acerto' -X 20 -Y 473 -Width 440 -Height 207
$form.Controls.Add($grpDamage)

$grpDamage.Controls.Add((New-Label -Text 'Dados:' -X 14 -Y 31 -Width 65))
$numDiceCount = New-Numeric -X 77 -Y 28 -Width 59 -Minimum 0 -Maximum 30 -Value 2
$grpDamage.Controls.Add($numDiceCount)
$lblD = New-Label -Text 'd' -X 141 -Y 31 -Width 18 -Height 24 -Size 11 -Bold $true
$grpDamage.Controls.Add($lblD)
$cmbFaces = New-Object System.Windows.Forms.ComboBox
$cmbFaces.Location = New-Object System.Drawing.Point(160, 28)
$cmbFaces.Size = New-Object System.Drawing.Size(70, 28)
$cmbFaces.DropDownStyle = [System.Windows.Forms.ComboBoxStyle]::DropDownList
[void]$cmbFaces.Items.AddRange(@('4','6','8','10','12','20','100'))
$cmbFaces.SelectedItem = '4'
$grpDamage.Controls.Add($cmbFaces)
$grpDamage.Controls.Add((New-Label -Text 'Modificador:' -X 242 -Y 31 -Width 95))
$numDamageModifier = New-Numeric -X 338 -Y 28 -Width 65 -Minimum -50 -Maximum 100 -Value 3
$grpDamage.Controls.Add($numDamageModifier)

$lblDamageExpression = New-Label -Text 'Expressão: 2d4+3' -X 14 -Y 67 -Width 389 -Height 28 -Size 11 -Bold $true
$lblDamageExpression.ForeColor = $colorGold
$grpDamage.Controls.Add($lblDamageExpression)

$rbAverage = New-Object System.Windows.Forms.RadioButton
$rbAverage.Text = 'Usar dano médio por acerto (recomendado pelo livro)'
$rbAverage.Location = New-Object System.Drawing.Point(17, 101)
$rbAverage.Size = New-Object System.Drawing.Size(395, 24)
$rbAverage.Checked = $true
$rbAverage.ForeColor = $colorText
$grpDamage.Controls.Add($rbAverage)

$rbOneRoll = New-Object System.Windows.Forms.RadioButton
$rbOneRoll.Text = 'Rolar uma vez e multiplicar pelos acertos'
$rbOneRoll.Location = New-Object System.Drawing.Point(17, 132)
$rbOneRoll.Size = New-Object System.Drawing.Size(395, 24)
$rbOneRoll.ForeColor = $colorText
$grpDamage.Controls.Add($rbOneRoll)

$rbIndividual = New-Object System.Windows.Forms.RadioButton
$rbIndividual.Text = 'Rolar o dano individualmente para cada acerto'
$rbIndividual.Location = New-Object System.Drawing.Point(17, 163)
$rbIndividual.Size = New-Object System.Drawing.Size(395, 24)
$rbIndividual.ForeColor = $colorText
$grpDamage.Controls.Add($rbIndividual)

# ----- Botão principal
$btnResolve = New-Button -Text 'RESOLVER / PRÓXIMO ATAQUE' -X 20 -Y 692 -Width 440 -Height 44 -BackColor ([System.Drawing.Color]::FromArgb(116, 80, 37))
$btnResolve.Font = New-Object System.Drawing.Font('Segoe UI', 12, [System.Drawing.FontStyle]::Bold)
$form.Controls.Add($btnResolve)

# ----- Resultado
$grpResult = New-GroupBox -Text 'Resultado' -X 480 -Y 72 -Width 540 -Height 218
$form.Controls.Add($grpResult)

$lblHitsCaption = New-Label -Text 'ACERTOS' -X 20 -Y 30 -Width 150 -Height 25 -Size 10 -Bold $true
$lblHitsCaption.ForeColor = $colorMuted
$grpResult.Controls.Add($lblHitsCaption)
$lblHits = New-Label -Text '—' -X 20 -Y 55 -Width 230 -Height 62 -Size 30 -Bold $true
$lblHits.ForeColor = $colorGreen
$grpResult.Controls.Add($lblHits)

$lblDamageCaption = New-Label -Text 'DANO TOTAL' -X 280 -Y 30 -Width 180 -Height 25 -Size 10 -Bold $true
$lblDamageCaption.ForeColor = $colorMuted
$grpResult.Controls.Add($lblDamageCaption)
$lblTotalDamage = New-Label -Text '—' -X 280 -Y 55 -Width 230 -Height 62 -Size 30 -Bold $true
$lblTotalDamage.ForeColor = $colorGold
$grpResult.Controls.Add($lblTotalDamage)

$lblRequired = New-Label -Text 'Jogada necessária: —' -X 20 -Y 127 -Width 245 -Height 25 -Size 10 -Bold $true
$grpResult.Controls.Add($lblRequired)
$lblTableRow = New-Label -Text 'Linha da tabela: —' -X 280 -Y 127 -Width 230 -Height 25 -Size 10 -Bold $true
$grpResult.Controls.Add($lblTableRow)
$lblTotalHP = New-Label -Text 'Referência: CA 15 • 70 PV teóricos no bando' -X 20 -Y 164 -Width 490 -Height 28 -Size 10
$lblTotalHP.ForeColor = $colorMuted
$grpResult.Controls.Add($lblTotalHP)

# ----- Detalhes
$grpDetails = New-GroupBox -Text 'Detalhes da resolução' -X 480 -Y 300 -Width 540 -Height 257
$form.Controls.Add($grpDetails)
$txtDetails = New-Object System.Windows.Forms.RichTextBox
$txtDetails.Location = New-Object System.Drawing.Point(14, 25)
$txtDetails.Size = New-Object System.Drawing.Size(512, 217)
$txtDetails.ReadOnly = $true
$txtDetails.BackColor = [System.Drawing.Color]::FromArgb(31, 34, 40)
$txtDetails.ForeColor = $colorText
$txtDetails.BorderStyle = [System.Windows.Forms.BorderStyle]::FixedSingle
$txtDetails.Font = New-Object System.Drawing.Font('Consolas', 9.5)
$txtDetails.Text = 'Configure o ataque e clique em RESOLVER / PRÓXIMO ATAQUE.'
$grpDetails.Controls.Add($txtDetails)

# ----- Histórico
$grpHistory = New-GroupBox -Text 'Histórico da sessão' -X 480 -Y 567 -Width 540 -Height 169
$form.Controls.Add($grpHistory)
$txtHistory = New-Object System.Windows.Forms.RichTextBox
$txtHistory.Location = New-Object System.Drawing.Point(14, 25)
$txtHistory.Size = New-Object System.Drawing.Size(392, 128)
$txtHistory.ReadOnly = $true
$txtHistory.BackColor = [System.Drawing.Color]::FromArgb(31, 34, 40)
$txtHistory.ForeColor = $colorText
$txtHistory.BorderStyle = [System.Windows.Forms.BorderStyle]::FixedSingle
$txtHistory.Font = New-Object System.Drawing.Font('Consolas', 9)
$grpHistory.Controls.Add($txtHistory)
$btnCopy = New-Button -Text 'Copiar resumo' -X 418 -Y 26 -Width 107 -Height 38
$grpHistory.Controls.Add($btnCopy)
$btnClearHistory = New-Button -Text 'Limpar histórico' -X 418 -Y 72 -Width 107 -Height 38
$grpHistory.Controls.Add($btnClearHistory)
$btnAbout = New-Button -Text 'Como funciona?' -X 418 -Y 118 -Width 107 -Height 34
$grpHistory.Controls.Add($btnAbout)

# -----------------------------------------------------------------------------
# ATUALIZAÇÕES DA INTERFACE
# -----------------------------------------------------------------------------
function Update-DamagePreview {
    $expression = Format-DamageExpression -DiceCount ([int]$numDiceCount.Value) -Faces ([int]$cmbFaces.SelectedItem) -Modifier ([int]$numDamageModifier.Value)
    $lblDamageExpression.Text = 'Expressão: ' + $expression
}

function Update-NeededPreview {
    $needed = [int]$numTargetAC.Value - [int]$numAttackBonus.Value
    $lblNeededPreview.Text = 'Jogada necessária: ' + $needed
}

function Update-ReferencePreview {
    $quantity = [int]$numQuantity.Value
    $hp = [int]$numMonsterHP.Value
    $ac = [int]$numMonsterAC.Value
    $lblTotalHP.Text = ('Referência: CA {0} • {1} PV teóricos no bando ({2} × {3})' -f $ac, ($quantity * $hp), $quantity, $hp)
}

function Refresh-ModelsCombo {
    $selectedName = $null
    if ($cmbModels.SelectedIndex -gt 0) { $selectedName = [string]$cmbModels.SelectedItem }

    $script:IsLoadingModel = $true
    $cmbModels.Items.Clear()
    [void]$cmbModels.Items.Add('Personalizado')
    foreach ($model in @($script:Models | Sort-Object Nome)) {
        [void]$cmbModels.Items.Add([string]$model.Nome)
    }
    if ($selectedName -and $cmbModels.Items.Contains($selectedName)) {
        $cmbModels.SelectedItem = $selectedName
    }
    else {
        $cmbModels.SelectedIndex = 0
    }
    $script:IsLoadingModel = $false
}

function Apply-SelectedModel {
    if ($script:IsLoadingModel -or $cmbModels.SelectedIndex -le 0) { return }
    $name = [string]$cmbModels.SelectedItem
    $model = @($script:Models | Where-Object { $_.Nome -eq $name } | Select-Object -First 1)
    if ($model.Count -eq 0) { return }
    $model = $model[0]

    $script:IsLoadingModel = $true
    $txtMonsterName.Text = [string]$model.Nome
    $numAttackBonus.Value = [decimal]$model.BonusAtaque
    $numDiceCount.Value = [decimal]$model.DadoQtd
    $cmbFaces.SelectedItem = [string]$model.DadoFaces
    $numDamageModifier.Value = [decimal]$model.ModDano
    $numMonsterAC.Value = [decimal]$model.CAMonstro
    $numMonsterHP.Value = [decimal]$model.PVMonstro
    $numInitiativeBonus.Value = [decimal]$model.BonusIniciativa
    if ($model.MetodoDano -eq 'UmaRolagem') { $rbOneRoll.Checked = $true }
    elseif ($model.MetodoDano -eq 'Individual') { $rbIndividual.Checked = $true }
    else { $rbAverage.Checked = $true }
    $script:IsLoadingModel = $false

    Update-DamagePreview
    Update-NeededPreview
    Update-ReferencePreview
}

# -----------------------------------------------------------------------------
# EVENTOS
# -----------------------------------------------------------------------------
$btnQMinus5.Add_Click({ $numQuantity.Value = [Math]::Max([decimal]$numQuantity.Minimum, $numQuantity.Value - 5) })
$btnQMinus1.Add_Click({ $numQuantity.Value = [Math]::Max([decimal]$numQuantity.Minimum, $numQuantity.Value - 1) })
$btnQPlus1.Add_Click({ $numQuantity.Value = [Math]::Min([decimal]$numQuantity.Maximum, $numQuantity.Value + 1) })
$btnQPlus5.Add_Click({ $numQuantity.Value = [Math]::Min([decimal]$numQuantity.Maximum, $numQuantity.Value + 5) })

$numQuantity.Add_ValueChanged({ Update-ReferencePreview })
$numMonsterHP.Add_ValueChanged({ Update-ReferencePreview })
$numMonsterAC.Add_ValueChanged({ Update-ReferencePreview })
$numTargetAC.Add_ValueChanged({ Update-NeededPreview })
$numAttackBonus.Add_ValueChanged({ Update-NeededPreview })
$numDiceCount.Add_ValueChanged({ Update-DamagePreview })
$cmbFaces.Add_SelectedIndexChanged({ Update-DamagePreview })
$numDamageModifier.Add_ValueChanged({ Update-DamagePreview })
$cmbModels.Add_SelectedIndexChanged({ Apply-SelectedModel })

$btnInitiative.Add_Click({
    $roll = Get-Random -Minimum 1 -Maximum 21
    $bonus = [int]$numInitiativeBonus.Value
    $total = $roll + $bonus
    $script:LastInitiative = [string]$total
    $sign = if ($bonus -ge 0) { '+' } else { '' }
    $lblInitiative.Text = ('Iniciativa: {0}  (d20: {1} {2}{3})' -f $total, $roll, $sign, $bonus)
})

$btnSaveModel.Add_Click({
    $name = $txtMonsterName.Text.Trim()
    if ([string]::IsNullOrWhiteSpace($name)) {
        [System.Windows.Forms.MessageBox]::Show('Digite um nome para o monstro antes de salvar.', 'Modelo sem nome', [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Information) | Out-Null
        return
    }

    $method = if ($rbOneRoll.Checked) { 'UmaRolagem' } elseif ($rbIndividual.Checked) { 'Individual' } else { 'Médio' }
    $existing = @($script:Models | Where-Object { $_.Nome -eq $name } | Select-Object -First 1)
    if ($existing.Count -gt 0) {
        $answer = [System.Windows.Forms.MessageBox]::Show('Já existe um modelo com esse nome. Deseja substituí-lo?', 'Substituir modelo', [System.Windows.Forms.MessageBoxButtons]::YesNo, [System.Windows.Forms.MessageBoxIcon]::Question)
        if ($answer -ne [System.Windows.Forms.DialogResult]::Yes) { return }
        $script:Models = @($script:Models | Where-Object { $_.Nome -ne $name })
    }

    $script:Models += [PSCustomObject]@{
        Nome            = $name
        BonusAtaque     = [int]$numAttackBonus.Value
        DadoQtd         = [int]$numDiceCount.Value
        DadoFaces       = [int]$cmbFaces.SelectedItem
        ModDano         = [int]$numDamageModifier.Value
        CAMonstro       = [int]$numMonsterAC.Value
        PVMonstro       = [int]$numMonsterHP.Value
        BonusIniciativa = [int]$numInitiativeBonus.Value
        MetodoDano      = $method
    }

    if (Save-ModelsFile) {
        Refresh-ModelsCombo
        $cmbModels.SelectedItem = $name
    }
})

$btnDeleteModel.Add_Click({
    if ($cmbModels.SelectedIndex -le 0) {
        [System.Windows.Forms.MessageBox]::Show('Selecione um modelo salvo para excluir.', 'Nenhum modelo selecionado', [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Information) | Out-Null
        return
    }
    $name = [string]$cmbModels.SelectedItem
    $answer = [System.Windows.Forms.MessageBox]::Show(('Excluir o modelo "{0}"?' -f $name), 'Excluir modelo', [System.Windows.Forms.MessageBoxButtons]::YesNo, [System.Windows.Forms.MessageBoxIcon]::Warning)
    if ($answer -eq [System.Windows.Forms.DialogResult]::Yes) {
        $script:Models = @($script:Models | Where-Object { $_.Nome -ne $name })
        if (Save-ModelsFile) { Refresh-ModelsCombo }
    }
})

$btnResolve.Add_Click({
    try {
        $quantity = [int]$numQuantity.Value
        $targetAC = [int]$numTargetAC.Value
        $bonus = [int]$numAttackBonus.Value
        $mode = [string]$cmbMode.SelectedItem
        $neededRaw = $targetAC - $bonus
        $row = Get-TableRow -Needed $neededRaw -Mode $mode
        $decomposition = Get-GroupDecomposition -Quantity $quantity

        $tableHits = 0
        foreach ($groupSize in @($decomposition.Groups)) {
            $tableHits += [int]$script:MobTable[$row][$groupSize]
        }

        $remainderHits = 0
        $criticalHits = 0
        $remainderDetails = New-Object System.Collections.Generic.List[string]
        for ($i = 1; $i -le $decomposition.Remainder; $i++) {
            $attack = Roll-D20Attack -Bonus $bonus -TargetAC $targetAC -Mode $mode
            $rollText = $attack.Rolls -join '/'
            if ($attack.Success) {
                $remainderHits++
                if ($attack.IsNatural20) { $criticalHits++ }
                $suffix = if ($attack.IsNatural20) { 'ACERTO CRÍTICO' } else { 'acerto' }
                $remainderDetails.Add(('Remanescente {0}: d20 {1}; escolhido {2}; total {3} — {4}.' -f $i, $rollText, $attack.Chosen, $attack.Total, $suffix))
            }
            else {
                $remainderDetails.Add(('Remanescente {0}: d20 {1}; escolhido {2}; total {3} — erro.' -f $i, $rollText, $attack.Chosen, $attack.Total))
            }
        }

        $totalHits = $tableHits + $remainderHits
        $diceCount = [int]$numDiceCount.Value
        $faces = [int]$cmbFaces.SelectedItem
        $modifier = [int]$numDamageModifier.Value
        $method = if ($rbOneRoll.Checked) { 'UmaRolagem' } elseif ($rbIndividual.Checked) { 'Individual' } else { 'Médio' }
        $damage = Resolve-Damage -TotalHits $totalHits -CriticalHits $criticalHits -DiceCount $diceCount -Faces $faces -Modifier $modifier -Method $method

        $groupText = Get-GroupSummaryText -Groups @($decomposition.Groups) -Row $row
        $expression = Format-DamageExpression -DiceCount $diceCount -Faces $faces -Modifier $modifier
        $monsterName = $txtMonsterName.Text.Trim()
        if ([string]::IsNullOrWhiteSpace($monsterName)) { $monsterName = 'Monstro' }

        $detailsLines = New-Object System.Collections.Generic.List[string]
        $detailsLines.Add(('Monstro: {0}' -f $monsterName))
        $detailsLines.Add(('Cálculo: CA {0} - bônus {1} = jogada necessária {2}.' -f $targetAC, $bonus, $neededRaw))
        $detailsLines.Add(('Condição: {0}; linha usada na tabela: {1}.' -f $mode, $row))
        $detailsLines.Add(('Composição: {0}' -f $groupText))
        if ($decomposition.Remainder -gt 0) {
            $detailsLines.Add(('Remanescentes fora da tabela: {0}; rolados individualmente.' -f $decomposition.Remainder))
            foreach ($line in $remainderDetails) { $detailsLines.Add($line) }
        }
        $detailsLines.Add(('Acertos da tabela: {0}; acertos remanescentes: {1}; críticos remanescentes: {2}.' -f $tableHits, $remainderHits, $criticalHits))
        $detailsLines.Add(('Dano por acerto: {0}; método: {1}.' -f $expression, $method))
        $detailsLines.Add($damage.Details)
        $detailsLines.Add('Observação: a tabela de Bandos não separa acertos críticos. Críticos só aparecem nos poucos ataques remanescentes rolados individualmente.')

        $lblHits.Text = ('{0} / {1}' -f $totalHits, $quantity)
        $lblTotalDamage.Text = [string]$damage.Total
        $lblRequired.Text = ('Jogada necessária: {0}' -f $neededRaw)
        $lblTableRow.Text = ('Linha da tabela: {0}' -f $row)
        $txtDetails.Text = $detailsLines -join [Environment]::NewLine

        $time = Get-Date -Format 'HH:mm:ss'
        $historyLine = ('[{0}] {1}: {2}/{3} acertos, {4} dano, CA alvo {5}, {6}.' -f $time, $monsterName, $totalHits, $quantity, $damage.Total, $targetAC, $mode)
        if ($txtHistory.TextLength -gt 0) { $txtHistory.AppendText([Environment]::NewLine) }
        $txtHistory.AppendText($historyLine)
        $txtHistory.SelectionStart = $txtHistory.TextLength
        $txtHistory.ScrollToCaret()

        $script:LastSummary = ('{0}: {1} de {2} ataques acertaram e causaram {3} pontos de dano. Jogada necessária {4}; condição {5}; dano {6}.' -f $monsterName, $totalHits, $quantity, $damage.Total, $neededRaw, $mode, $expression)
    }
    catch {
        [System.Windows.Forms.MessageBox]::Show(
            'Ocorreu um erro ao resolver o bando.' + [Environment]::NewLine + $_.Exception.Message,
            'Erro',
            [System.Windows.Forms.MessageBoxButtons]::OK,
            [System.Windows.Forms.MessageBoxIcon]::Error
        ) | Out-Null
    }
})

$btnCopy.Add_Click({
    if ([string]::IsNullOrWhiteSpace($script:LastSummary)) {
        [System.Windows.Forms.MessageBox]::Show('Resolva um ataque antes de copiar o resumo.', 'Nada para copiar', [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Information) | Out-Null
        return
    }
    [System.Windows.Forms.Clipboard]::SetText($script:LastSummary)
    $btnCopy.Text = 'Copiado!'
    $timer = New-Object System.Windows.Forms.Timer
    $timer.Interval = 1200
    $timer.Add_Tick({
        param($sender, $eventArgs)
        $btnCopy.Text = 'Copiar resumo'
        $sender.Stop()
        $sender.Dispose()
    })
    $timer.Start()
})

$btnClearHistory.Add_Click({
    $txtHistory.Clear()
    $script:LastSummary = ''
})

$btnAbout.Add_Click({
    $message = @'
1. Informe a quantidade, a CA do alvo e o bônus de ataque.
2. Escolha Normal, Vantagem ou Desvantagem.
3. Selecione os dados e o método de dano.
4. Clique em RESOLVER / PRÓXIMO ATAQUE.

O programa divide a multidão em grupos de 4, 5, 6, 8 e 10, aplica a tabela oficial e rola individualmente apenas eventuais remanescentes de 1 a 3 criaturas.

Dano médio é o método mais rápido e o recomendado pelo Livro do Mestre. "Uma rolagem" mantém alguma aleatoriedade. "Individual" rola cada acerto separadamente.

Modelos são salvos no arquivo Bandos.modelos.json, na mesma pasta do programa.
'@
    [System.Windows.Forms.MessageBox]::Show($message, 'Como funciona', [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Information) | Out-Null
})

$form.Add_Shown({
    Load-Models
    Refresh-ModelsCombo
    Update-DamagePreview
    Update-NeededPreview
    Update-ReferencePreview
    $form.Activate()
})

[void]$form.ShowDialog()
