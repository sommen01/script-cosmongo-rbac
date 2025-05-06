Add-Type -AssemblyName System.Windows.Forms
[System.Windows.Forms.Application]::EnableVisualStyles()

function Listar-Contas-MongoDB {
    $accounts = az cosmosdb list | ConvertFrom-Json
    return $accounts | Where-Object { $_.kind -eq "MongoDB" -or $_.connectorOffer -like "*MongoDB*" }
}

function Adicionar-Usuario {
    param($account)

    $form = New-Object System.Windows.Forms.Form
    $form.Text = "Adicionar Usuário MongoDB - $($account.name)"
    $form.Size = New-Object System.Drawing.Size(400,300)
    $form.StartPosition = "CenterScreen"

    $labelUser = New-Object System.Windows.Forms.Label
    $labelUser.Text = "Usuário:"
    $labelUser.Location = New-Object System.Drawing.Point(10,20)
    $form.Controls.Add($labelUser)

    $textUser = New-Object System.Windows.Forms.TextBox
    $textUser.Location = New-Object System.Drawing.Point(100,20)
    $textUser.Width = 250
    $form.Controls.Add($textUser)

    $labelPass = New-Object System.Windows.Forms.Label
    $labelPass.Text = "Senha:"
    $labelPass.Location = New-Object System.Drawing.Point(10,60)
    $form.Controls.Add($labelPass)

    $textPass = New-Object System.Windows.Forms.TextBox
    $textPass.Location = New-Object System.Drawing.Point(100,60)
    $textPass.Width = 250
    $textPass.UseSystemPasswordChar = $true
    $form.Controls.Add($textPass)

    $labelDb = New-Object System.Windows.Forms.Label
    $labelDb.Text = "Banco de Dados:"
    $labelDb.Location = New-Object System.Drawing.Point(10,100)
    $form.Controls.Add($labelDb)

    $comboDb = New-Object System.Windows.Forms.ComboBox
    $comboDb.Location = New-Object System.Drawing.Point(100,100)
    $comboDb.Width = 250
    $form.Controls.Add($comboDb)

    $labelRole = New-Object System.Windows.Forms.Label
    $labelRole.Text = "Permissão:"
    $labelRole.Location = New-Object System.Drawing.Point(10,140)
    $form.Controls.Add($labelRole)

    $comboRole = New-Object System.Windows.Forms.ComboBox
    $comboRole.Location = New-Object System.Drawing.Point(100,140)
    $comboRole.Width = 250
    $comboRole.Items.AddRange(@("read", "readWrite", "dbAdmin", "dbOwner", "userAdmin"))
    $comboRole.SelectedIndex = 1
    $form.Controls.Add($comboRole)

    $okButton = New-Object System.Windows.Forms.Button
    $okButton.Text = "Criar"
    $okButton.Location = New-Object System.Drawing.Point(100, 190)
    $okButton.Add_Click({
        if ($textUser.Text -and $textPass.Text -and $comboDb.SelectedItem -and $comboRole.SelectedItem) {
            $form.DialogResult = [System.Windows.Forms.DialogResult]::OK
            $form.Close()
        } else {
            [System.Windows.Forms.MessageBox]::Show("Preencha todos os campos.", "Erro", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Warning)
        }
    })
    $form.Controls.Add($okButton)

    # Carregar bancos de dados
    $dbs = az cosmosdb mongodb database list `
        --account-name $account.name `
        --resource-group $account.resourceGroup `
        | ConvertFrom-Json | ForEach-Object { $_.name }

    $comboDb.Items.AddRange($dbs)

    if ($form.ShowDialog() -eq "OK") {
        $dbName = $comboDb.SelectedItem
        $userName = $textUser.Text
        $password = $textPass.Text
        $role = $comboRole.SelectedItem

        $body = @{
            Id = "$dbName.$userName"
            UserName = "$userName"
            Password = "$password"
            DatabaseName = $dbName
            CustomData = ""
            Mechanisms = "SCRAM-SHA-256"
            Roles = @(
                @{
                    Role = $role
                    Db = $dbName
                }
            )
        }

        $tempPath = [System.IO.Path]::GetTempFileName() + ".json"
        $body | ConvertTo-Json -Depth 10 | Out-File -Encoding UTF8 $tempPath

        az cosmosdb mongodb user definition create `
            --account-name $account.name `
            --resource-group $account.resourceGroup `
            --body "@$tempPath"

        Remove-Item $tempPath
        Write-Host "`nUsuário criado com sucesso."
    }
}

function Remover-Usuario {
    param($account)

    $form = New-Object System.Windows.Forms.Form
    $form.Text = "Remover Usuário MongoDB - $($account.name)"
    $form.Size = New-Object System.Drawing.Size(400,220)
    $form.StartPosition = "CenterScreen"

    $labelDb = New-Object System.Windows.Forms.Label
    $labelDb.Text = "Banco de Dados:"
    $labelDb.Location = New-Object System.Drawing.Point(10,20)
    $form.Controls.Add($labelDb)

    $comboDb = New-Object System.Windows.Forms.ComboBox
    $comboDb.Location = New-Object System.Drawing.Point(120,20)
    $comboDb.Width = 250
    $form.Controls.Add($comboDb)

    $labelUser = New-Object System.Windows.Forms.Label
    $labelUser.Text = "Usuário:"
    $labelUser.Location = New-Object System.Drawing.Point(10,60)
    $form.Controls.Add($labelUser)

    $comboUser = New-Object System.Windows.Forms.ComboBox
    $comboUser.Location = New-Object System.Drawing.Point(120,60)
    $comboUser.Width = 250
    $form.Controls.Add($comboUser)

    $deleteButton = New-Object System.Windows.Forms.Button
    $deleteButton.Text = "Remover"
    $deleteButton.Location = New-Object System.Drawing.Point(120, 110)
    $deleteButton.Add_Click({
        if ($comboDb.SelectedItem -and $comboUser.SelectedItem) {
            $form.DialogResult = [System.Windows.Forms.DialogResult]::OK
            $form.Close()
        } else {
            [System.Windows.Forms.MessageBox]::Show("Selecione um banco e um usuário.", "Erro", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Warning)
        }
    })
    $form.Controls.Add($deleteButton)

    # Carregar bancos
    $dbs = az cosmosdb mongodb database list `
        --account-name $account.name `
        --resource-group $account.resourceGroup `
        | ConvertFrom-Json | ForEach-Object { $_.name }

    $comboDb.Items.AddRange($dbs)

    $comboDb.Add_SelectedIndexChanged({
        $dbName = $comboDb.SelectedItem
        $users = az cosmosdb mongodb user definition list `
            --account-name $account.name `
            --resource-group $account.resourceGroup `
            | ConvertFrom-Json | Where-Object { $_.DatabaseName -eq $dbName }

        $comboUser.Items.Clear()
        foreach ($user in $users) {
            $comboUser.Items.Add($user.UserName)
        }
    })

    if ($form.ShowDialog() -eq "OK") {
        $dbName = $comboDb.SelectedItem
        $userName = $comboUser.SelectedItem
        $id = "$dbName.$userName"

        az cosmosdb mongodb user definition delete `
            --account-name $account.name `
            --resource-group $account.resourceGroup `
            --id $id

        Write-Host "`nUsuário removido com sucesso."
    }
}

# ---------- Menu Principal ----------
$accounts = Listar-Contas-MongoDB
if (-not $accounts) {
    Write-Host "Nenhuma conta MongoDB encontrada."
    return
}

$accountOptions = $accounts | ForEach-Object { "$($_.name) [$($_.resourceGroup)]" }
$accountChoice = [System.Windows.Forms.MessageBox]::Show("Deseja adicionar um usuário?", "MongoDB Cosmos", [System.Windows.Forms.MessageBoxButtons]::YesNoCancel)

if ($accountChoice -eq "Cancel") {
    return
}

$selected = $null
if ($accountOptions.Count -eq 1) {
    $selected = 0
} else {
    $selectionForm = New-Object System.Windows.Forms.Form
    $selectionForm.Text = "Selecione a Conta MongoDB"
    $selectionForm.Size = New-Object System.Drawing.Size(400,150)
    $selectionForm.StartPosition = "CenterScreen"

    $combo = New-Object System.Windows.Forms.ComboBox
    $combo.Location = New-Object System.Drawing.Point(30,30)
    $combo.Width = 320
    $combo.Items.AddRange($accountOptions)
    $selectionForm.Controls.Add($combo)

    $ok = New-Object System.Windows.Forms.Button
    $ok.Text = "Selecionar"
    $ok.Location = New-Object System.Drawing.Point(150,70)
    $ok.Add_Click({
        if ($combo.SelectedIndex -ne -1) {
            $selected = $combo.SelectedIndex
            $selectionForm.Close()
        }
    })
    $selectionForm.Controls.Add($ok)

    $selectionForm.ShowDialog() | Out-Null
}

if ($null -ne $selected) {
    $account = $accounts[$selected]
    if ($accountChoice -eq "Yes") {
        Adicionar-Usuario -account $account
    } elseif ($accountChoice -eq "No") {
        Remover-Usuario -account $account
    }
}
