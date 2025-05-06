Add-Type -AssemblyName System.Windows.Forms
[System.Windows.Forms.Application]::EnableVisualStyles()

function Get-CosmosDBAccounts {
    $accounts = az cosmosdb list | ConvertFrom-Json
    return $accounts | Where-Object { $_.kind -eq "MongoDB" -or $_.connectorOffer -like "*MongoDB*" }
}

function Get-CosmosDBDatabases {
    param (
        [string]$AccountName,
        [string]$ResourceGroupName
    )
    $databases = az cosmosdb mongodb database list --account-name $AccountName --resource-group $ResourceGroupName | ConvertFrom-Json
    return $databases | ForEach-Object { $_.name }
}

function Get-AvailablePermissions {
    return @(
        "read",
        "readWrite",
        "dbAdmin",
        "dbOwner",
        "userAdmin"
    )
}

function New-CosmosDBUser {
    param (
        [string]$AccountName,
        [string]$ResourceGroupName,
        [string]$Username,
        [string]$Password,
        [string]$Database,
        [string]$Role
    )
    
    $body = @{
        Id = "$Database.$Username"
        UserName = $Username
        Password = $Password
        DatabaseName = $Database
        CustomData = ""
        Mechanisms = "SCRAM-SHA-256"
        Roles = @(
            @{
                Role = $Role
                Db = $Database
            }
        )
    }

    $tempPath = [System.IO.Path]::GetTempFileName() + ".json"
    $body | ConvertTo-Json -Depth 10 | Out-File -Encoding UTF8 $tempPath

    az cosmosdb mongodb user definition create --account-name $AccountName --resource-group $ResourceGroupName --body "@$tempPath"
    Remove-Item $tempPath
}

function Remove-CosmosDBUser {
    param (
        [string]$AccountName,
        [string]$ResourceGroupName,
        [string]$Database,
        [string]$Username
    )
    
    $id = "$Database.$Username"
    az cosmosdb mongodb user definition delete --account-name $AccountName --resource-group $ResourceGroupName --id $id
}

function Show-ListUsersForm {
    param (
        [string]$AccountName,
        [string]$ResourceGroupName
    )
    $users = az cosmosdb mongodb user definition list --account-name $AccountName --resource-group $ResourceGroupName | ConvertFrom-Json
    $form = New-Object System.Windows.Forms.Form
    $form.Text = "Usuários MongoDB - $AccountName"
    $form.Size = New-Object System.Drawing.Size(900,700)
    $form.StartPosition = "CenterScreen"
    $form.Font = New-Object System.Drawing.Font("Segoe UI", 16)

    $list = New-Object System.Windows.Forms.ListBox
    $list.Location = New-Object System.Drawing.Point(50,50)
    $list.Size = New-Object System.Drawing.Size(800,500)
    $list.Font = $form.Font
    foreach ($user in $users) {
        $list.Items.Add("Usuário: $($user.UserName) | Banco: $($user.DatabaseName) | Permissão: $($user.Roles[0].Role)")
    }
    $form.Controls.Add($list)

    $closeBtn = New-Object System.Windows.Forms.Button
    $closeBtn.Text = "Voltar"
    $closeBtn.Location = New-Object System.Drawing.Point(350,600)
    $closeBtn.Size = New-Object System.Drawing.Size(200,60)
    $closeBtn.Font = $form.Font
    $closeBtn.Add_Click({ $form.Close() })
    $form.Controls.Add($closeBtn)

    $form.ShowDialog()
}

function Show-ListPermissionsForm {
    $form = New-Object System.Windows.Forms.Form
    $form.Text = "Permissões MongoDB"
    $form.Size = New-Object System.Drawing.Size(900,700)
    $form.StartPosition = "CenterScreen"
    $form.Font = New-Object System.Drawing.Font("Segoe UI", 16)

    $list = New-Object System.Windows.Forms.ListBox
    $list.Location = New-Object System.Drawing.Point(100,100)
    $list.Size = New-Object System.Drawing.Size(700,400)
    $list.Font = $form.Font
    $list.Items.AddRange((Get-AvailablePermissions))
    $form.Controls.Add($list)

    $closeBtn = New-Object System.Windows.Forms.Button
    $closeBtn.Text = "Voltar"
    $closeBtn.Location = New-Object System.Drawing.Point(350,600)
    $closeBtn.Size = New-Object System.Drawing.Size(200,60)
    $closeBtn.Font = $form.Font
    $closeBtn.Add_Click({ $form.Close() })
    $form.Controls.Add($closeBtn)

    $form.ShowDialog()
}

function Show-MainMenuForm {
    param (
        [string]$AccountName,
        [string]$ResourceGroupName
    )
    $form = New-Object System.Windows.Forms.Form
    $form.Text = "Menu CosmosDB MongoDB - $AccountName"
    $form.Size = New-Object System.Drawing.Size(900, 700)
    $form.StartPosition = "CenterScreen"
    $form.Font = New-Object System.Drawing.Font("Segoe UI", 16)

    $label = New-Object System.Windows.Forms.Label
    $label.Text = "Selecione uma opção:"
    $label.Location = New-Object System.Drawing.Point(100,100)
    $label.Size = New-Object System.Drawing.Size(700,40)
    $label.Font = $form.Font
    $form.Controls.Add($label)

    $options = @("Criar usuários", "Listar usuários", "Atualizar usuários", "Deletar usuários", "Listar permissões")
    $listBox = New-Object System.Windows.Forms.ListBox
    $listBox.Location = New-Object System.Drawing.Point(100,180)
    $listBox.Size = New-Object System.Drawing.Size(700,250)
    $listBox.Font = $form.Font
    $listBox.Items.AddRange($options)
    $form.Controls.Add($listBox)

    $okBtn = New-Object System.Windows.Forms.Button
    $okBtn.Text = "OK"
    $okBtn.Location = New-Object System.Drawing.Point(350,500)
    $okBtn.Size = New-Object System.Drawing.Size(200,60)
    $okBtn.Font = $form.Font
    $okBtn.Add_Click({
        if ($listBox.SelectedIndex -ne -1) {
            $form.Tag = $listBox.SelectedItem
            $form.Close()
        }
    })
    $form.Controls.Add($okBtn)

    $form.ShowDialog() | Out-Null
    return $form.Tag
}

function Show-CreateUserForm {
    param (
        [string]$AccountName,
        [string]$ResourceGroupName
    )
    $form = New-Object System.Windows.Forms.Form
    $form.Text = "Adicionar Usuário MongoDB - $AccountName"
    $form.Size = New-Object System.Drawing.Size(900, 700)
    $form.StartPosition = "CenterScreen"
    $form.Font = New-Object System.Drawing.Font("Segoe UI", 16)

    $labelUser = New-Object System.Windows.Forms.Label
    $labelUser.Text = "Usuário:"
    $labelUser.Location = New-Object System.Drawing.Point(30,40)
    $labelUser.Size = New-Object System.Drawing.Size(250,40)
    $form.Controls.Add($labelUser)

    $textUser = New-Object System.Windows.Forms.TextBox
    $textUser.Location = New-Object System.Drawing.Point(300,40)
    $textUser.Size = New-Object System.Drawing.Size(500,40)
    $textUser.Font = $form.Font
    $form.Controls.Add($textUser)

    $labelPass = New-Object System.Windows.Forms.Label
    $labelPass.Text = "Senha:"
    $labelPass.Location = New-Object System.Drawing.Point(30,110)
    $labelPass.Size = New-Object System.Drawing.Size(250,40)
    $form.Controls.Add($labelPass)

    $textPass = New-Object System.Windows.Forms.TextBox
    $textPass.Location = New-Object System.Drawing.Point(300,110)
    $textPass.Size = New-Object System.Drawing.Size(500,40)
    $textPass.Font = $form.Font
    $textPass.UseSystemPasswordChar = $true
    $form.Controls.Add($textPass)

    $labelDb = New-Object System.Windows.Forms.Label
    $labelDb.Text = "Banco de Dados:"
    $labelDb.Location = New-Object System.Drawing.Point(30,180)
    $labelDb.Size = New-Object System.Drawing.Size(250,40)
    $form.Controls.Add($labelDb)

    $comboDb = New-Object System.Windows.Forms.ComboBox
    $comboDb.Location = New-Object System.Drawing.Point(300,180)
    $comboDb.Size = New-Object System.Drawing.Size(500,40)
    $comboDb.Font = $form.Font
    $form.Controls.Add($comboDb)

    $labelRole = New-Object System.Windows.Forms.Label
    $labelRole.Text = "Permissão:"
    $labelRole.Location = New-Object System.Drawing.Point(30,250)
    $labelRole.Size = New-Object System.Drawing.Size(250,40)
    $form.Controls.Add($labelRole)

    $comboRole = New-Object System.Windows.Forms.ComboBox
    $comboRole.Location = New-Object System.Drawing.Point(300,250)
    $comboRole.Size = New-Object System.Drawing.Size(500,40)
    $comboRole.Font = $form.Font
    $comboRole.Items.AddRange((Get-AvailablePermissions))
    $comboRole.SelectedIndex = 1
    $form.Controls.Add($comboRole)

    $okButton = New-Object System.Windows.Forms.Button
    $okButton.Text = "Criar"
    $okButton.Location = New-Object System.Drawing.Point(300, 350)
    $okButton.Size = New-Object System.Drawing.Size(200,60)
    $okButton.Font = $form.Font
    $okButton.Add_Click({
        if ($textUser.Text -and $textPass.Text -and $comboDb.SelectedItem -and $comboRole.SelectedItem) {
            $logForm = New-Object System.Windows.Forms.Form
            $logForm.Text = "Log de Criação de Usuário"
            $logForm.Size = New-Object System.Drawing.Size(800, 600)
            $logForm.StartPosition = "CenterScreen"
            $logBox = New-Object System.Windows.Forms.TextBox
            $logBox.Multiline = $true
            $logBox.ScrollBars = "Vertical"
            $logBox.ReadOnly = $true
            $logBox.Dock = "Fill"
            $logForm.Controls.Add($logBox)
            $logForm.Show()

            $logBox.AppendText("Iniciando criação do usuário...`r`n")
            $logBox.AppendText("Preparando dados...`r`n")
            $body = @{
                Id = "$($comboDb.SelectedItem).$($textUser.Text)"
                UserName = $textUser.Text
                Password = $textPass.Text
                DatabaseName = $comboDb.SelectedItem
                CustomData = ""
                Mechanisms = "SCRAM-SHA-256"
                Roles = @(
                    @{
                        Role = $comboRole.SelectedItem
                        Db = $comboDb.SelectedItem
                    }
                )
            }
            $tempPath = [System.IO.Path]::GetTempFileName() + ".json"
            $body | ConvertTo-Json -Depth 10 | Out-File -Encoding UTF8 $tempPath
            $logBox.AppendText("Arquivo temporário criado: $tempPath`r`n")
            $logBox.AppendText("Executando comando Azure CLI...`r`n")
            $output = & az cosmosdb mongodb user definition create --account-name $AccountName --resource-group $ResourceGroupName --body "@$tempPath" 2>&1
            $logBox.AppendText(($output -join "`r`n") + "`r`n")
            Remove-Item $tempPath
            if ($output -like '*error*' -or $output -like '*Error*') {
                $logBox.AppendText("Erro ao criar usuário!`r`n")
                [System.Windows.Forms.MessageBox]::Show("Erro ao criar usuário. Veja o log para detalhes.", "Erro", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Error)
            } else {
                $logBox.AppendText("Usuário criado com sucesso!`r`n")
                [System.Windows.Forms.MessageBox]::Show("Usuário criado com sucesso!", "Sucesso", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Information)
                $form.Close()
            }
            $logForm.Close()
        } else {
            [System.Windows.Forms.MessageBox]::Show("Preencha todos os campos.", "Erro", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Warning)
        }
    })
    $form.Controls.Add($okButton)

    $backButton = New-Object System.Windows.Forms.Button
    $backButton.Text = "Voltar"
    $backButton.Location = New-Object System.Drawing.Point(520, 350)
    $backButton.Size = New-Object System.Drawing.Size(200,60)
    $backButton.Font = $form.Font
    $backButton.Add_Click({ $form.Close() })
    $form.Controls.Add($backButton)

    $dbs = Get-CosmosDBDatabases -AccountName $AccountName -ResourceGroupName $ResourceGroupName
    $comboDb.Items.AddRange($dbs)

    $form.ShowDialog()
}

function Show-RemoveUserForm {
    param (
        [string]$AccountName,
        [string]$ResourceGroupName
    )
    
    $form = New-Object System.Windows.Forms.Form
    $form.Text = "Remover Usuário MongoDB - $AccountName"
    $form.Size = New-Object System.Drawing.Size(900,700)
    $form.StartPosition = "CenterScreen"
    $form.Font = New-Object System.Drawing.Font("Segoe UI", 16)

    $labelDb = New-Object System.Windows.Forms.Label
    $labelDb.Text = "Banco de Dados:"
    $labelDb.Location = New-Object System.Drawing.Point(30,40)
    $labelDb.Size = New-Object System.Drawing.Size(250,40)
    $labelDb.Font = $form.Font
    $form.Controls.Add($labelDb)

    $comboDb = New-Object System.Windows.Forms.ComboBox
    $comboDb.Location = New-Object System.Drawing.Point(300,40)
    $comboDb.Size = New-Object System.Drawing.Size(500,40)
    $comboDb.Font = $form.Font
    $form.Controls.Add($comboDb)

    $labelUser = New-Object System.Windows.Forms.Label
    $labelUser.Text = "Usuário:"
    $labelUser.Location = New-Object System.Drawing.Point(30,110)
    $labelUser.Size = New-Object System.Drawing.Size(250,40)
    $labelUser.Font = $form.Font
    $form.Controls.Add($labelUser)

    $comboUser = New-Object System.Windows.Forms.ComboBox
    $comboUser.Location = New-Object System.Drawing.Point(300,110)
    $comboUser.Size = New-Object System.Drawing.Size(500,40)
    $comboUser.Font = $form.Font
    $form.Controls.Add($comboUser)

    $deleteButton = New-Object System.Windows.Forms.Button
    $deleteButton.Text = "Remover"
    $deleteButton.Location = New-Object System.Drawing.Point(300, 200)
    $deleteButton.Size = New-Object System.Drawing.Size(200,60)
    $deleteButton.Font = $form.Font
    $deleteButton.Add_Click({
        if ($comboDb.SelectedItem -and $comboUser.SelectedItem) {
            $logForm = New-Object System.Windows.Forms.Form
            $logForm.Text = "Log de Remoção de Usuário"
            $logForm.Size = New-Object System.Drawing.Size(800, 600)
            $logForm.StartPosition = "CenterScreen"
            $logBox = New-Object System.Windows.Forms.TextBox
            $logBox.Multiline = $true
            $logBox.ScrollBars = "Vertical"
            $logBox.ReadOnly = $true
            $logBox.Dock = "Fill"
            $logForm.Controls.Add($logBox)
            $logForm.Show()

            $logBox.AppendText("Removendo usuário...`r`n")
            $job = Start-Job -ScriptBlock {
                param($AccountName, $ResourceGroupName, $Db, $User)
                & az cosmosdb mongodb user definition delete --account-name $AccountName --resource-group $ResourceGroupName --id "$Db.$User" --yes 2>&1
            } -ArgumentList $AccountName, $ResourceGroupName, $comboDb.SelectedItem, $comboUser.SelectedItem

            Wait-Job $job
            $output = Receive-Job $job
            Remove-Job $job

            $logBox.AppendText(($output -join "`r`n") + "`r`n")
            if ($output -like '*error*' -or $output -like '*Error*') {
                $logBox.AppendText("Erro ao remover usuário!`r`n")
                [System.Windows.Forms.MessageBox]::Show("Erro ao remover usuário. Veja o log para detalhes.", "Erro", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Error)
            } else {
                $logBox.AppendText("Usuário removido com sucesso!`r`n")
                [System.Windows.Forms.MessageBox]::Show("Usuário removido com sucesso!", "Sucesso", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Information)
                $form.Close()
            }
            $logForm.Close()
        } else {
            [System.Windows.Forms.MessageBox]::Show("Selecione um banco e um usuário.", "Erro", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Warning)
        }
    })
    $form.Controls.Add($deleteButton)

    $backButton = New-Object System.Windows.Forms.Button
    $backButton.Text = "Voltar"
    $backButton.Location = New-Object System.Drawing.Point(520, 200)
    $backButton.Size = New-Object System.Drawing.Size(200,60)
    $backButton.Font = $form.Font
    $backButton.Add_Click({ $form.Close() })
    $form.Controls.Add($backButton)

    $dbs = Get-CosmosDBDatabases -AccountName $AccountName -ResourceGroupName $ResourceGroupName
    $comboDb.Items.AddRange($dbs)

    $comboDb.Add_SelectedIndexChanged({
        $dbName = $comboDb.SelectedItem
        $users = az cosmosdb mongodb user definition list --account-name $AccountName --resource-group $ResourceGroupName | ConvertFrom-Json | Where-Object { $_.DatabaseName -eq $dbName }

        $comboUser.Items.Clear()
        foreach ($user in $users) {
            $comboUser.Items.Add($user.UserName)
        }
    })

    $form.ShowDialog()
}

function Show-LogWindow {
    param([string]$Title = "Log de Execução")
    $logForm = New-Object System.Windows.Forms.Form
    $logForm.Text = $Title
    $logForm.Size = New-Object System.Drawing.Size(600, 400)
    $logForm.StartPosition = "CenterScreen"

    $logBox = New-Object System.Windows.Forms.TextBox
    $logBox.Multiline = $true
    $logBox.ScrollBars = "Vertical"
    $logBox.ReadOnly = $true
    $logBox.Dock = "Fill"
    $logForm.Controls.Add($logBox)

    $logForm.Show()
    return $logBox
}

function Show-UpdateUserForm {
    param (
        [string]$AccountName,
        [string]$ResourceGroupName
    )

    $form = New-Object System.Windows.Forms.Form
    $form.Text = "Atualizar Usuário MongoDB - $AccountName"
    $form.Size = New-Object System.Drawing.Size(900, 700)
    $form.StartPosition = "CenterScreen"
    $form.Font = New-Object System.Drawing.Font("Segoe UI", 16)

    $labelDb = New-Object System.Windows.Forms.Label
    $labelDb.Text = "Banco de Dados:"
    $labelDb.Location = New-Object System.Drawing.Point(30,40)
    $labelDb.Size = New-Object System.Drawing.Size(250,40)
    $form.Controls.Add($labelDb)

    $comboDb = New-Object System.Windows.Forms.ComboBox
    $comboDb.Location = New-Object System.Drawing.Point(300,40)
    $comboDb.Size = New-Object System.Drawing.Size(500,40)
    $comboDb.Font = $form.Font
    $form.Controls.Add($comboDb)

    $labelUser = New-Object System.Windows.Forms.Label
    $labelUser.Text = "Usuário:"
    $labelUser.Location = New-Object System.Drawing.Point(30,110)
    $labelUser.Size = New-Object System.Drawing.Size(250,40)
    $form.Controls.Add($labelUser)

    $comboUser = New-Object System.Windows.Forms.ComboBox
    $comboUser.Location = New-Object System.Drawing.Point(300,110)
    $comboUser.Size = New-Object System.Drawing.Size(500,40)
    $comboUser.Font = $form.Font
    $form.Controls.Add($comboUser)

    $labelPass = New-Object System.Windows.Forms.Label
    $labelPass.Text = "Nova Senha:"
    $labelPass.Location = New-Object System.Drawing.Point(30,180)
    $labelPass.Size = New-Object System.Drawing.Size(250,40)
    $form.Controls.Add($labelPass)

    $textPass = New-Object System.Windows.Forms.TextBox
    $textPass.Location = New-Object System.Drawing.Point(300,180)
    $textPass.Size = New-Object System.Drawing.Size(500,40)
    $textPass.Font = $form.Font
    $textPass.UseSystemPasswordChar = $true
    $form.Controls.Add($textPass)

    $labelRole = New-Object System.Windows.Forms.Label
    $labelRole.Text = "Nova Permissão:"
    $labelRole.Location = New-Object System.Drawing.Point(30,250)
    $labelRole.Size = New-Object System.Drawing.Size(250,40)
    $form.Controls.Add($labelRole)

    $comboRole = New-Object System.Windows.Forms.ComboBox
    $comboRole.Location = New-Object System.Drawing.Point(300,250)
    $comboRole.Size = New-Object System.Drawing.Size(500,40)
    $comboRole.Font = $form.Font
    $comboRole.Items.AddRange((Get-AvailablePermissions))
    $form.Controls.Add($comboRole)

    $updateButton = New-Object System.Windows.Forms.Button
    $updateButton.Text = "Atualizar"
    $updateButton.Location = New-Object System.Drawing.Point(300, 350)
    $updateButton.Size = New-Object System.Drawing.Size(200,60)
    $updateButton.Font = $form.Font
    $form.Controls.Add($updateButton)

    $backButton = New-Object System.Windows.Forms.Button
    $backButton.Text = "Voltar"
    $backButton.Location = New-Object System.Drawing.Point(520, 350)
    $backButton.Size = New-Object System.Drawing.Size(200,60)
    $backButton.Font = $form.Font
    $backButton.Add_Click({ $form.Close() })
    $form.Controls.Add($backButton)

    $dbs = Get-CosmosDBDatabases -AccountName $AccountName -ResourceGroupName $ResourceGroupName
    $comboDb.Items.AddRange($dbs)

    $comboDb.Add_SelectedIndexChanged({
        $dbName = $comboDb.SelectedItem
        $users = az cosmosdb mongodb user definition list --account-name $AccountName --resource-group $ResourceGroupName | ConvertFrom-Json | Where-Object { $_.DatabaseName -eq $dbName }
        $comboUser.Items.Clear()
        foreach ($user in $users) {
            $comboUser.Items.Add($user.UserName)
        }
    })

    $comboUser.Add_SelectedIndexChanged({
        $dbName = $comboDb.SelectedItem
        $userName = $comboUser.SelectedItem
        $users = az cosmosdb mongodb user definition list --account-name $AccountName --resource-group $ResourceGroupName | ConvertFrom-Json | Where-Object { $_.DatabaseName -eq $dbName -and $_.UserName -eq $userName }
        if ($users.Count -gt 0) {
            $user = $users[0]
            $textPass.Text = $user.Password 
            $comboRole.SelectedItem = $user.Roles[0].Role
        }
    })

    $updateButton.Add_Click({
        if ($comboDb.SelectedItem -and $comboUser.SelectedItem -and $comboRole.SelectedItem) {
            $logForm = New-Object System.Windows.Forms.Form
            $logForm.Text = "Log de Atualização de Usuário"
            $logForm.Size = New-Object System.Drawing.Size(800, 600)
            $logForm.StartPosition = "CenterScreen"
            $logBox = New-Object System.Windows.Forms.TextBox
            $logBox.Multiline = $true
            $logBox.ScrollBars = "Vertical"
            $logBox.ReadOnly = $true
            $logBox.Dock = "Fill"
            $logForm.Controls.Add($logBox)
            $logForm.Show()

            $logBox.AppendText("Atualizando usuário...`r`n")
            $body = @{
                Id = "$($comboDb.SelectedItem).$($comboUser.SelectedItem)"
                UserName = $comboUser.SelectedItem
                DatabaseName = $comboDb.SelectedItem
                CustomData = ""
                Mechanisms = "SCRAM-SHA-256"
                Roles = @(
                    @{
                        Role = $comboRole.SelectedItem
                        Db = $comboDb.SelectedItem
                    }
                )
            }
            if ($textPass.Text) {
                $body.Password = $textPass.Text
            }
            $tempPath = [System.IO.Path]::GetTempFileName() + ".json"
            $body | ConvertTo-Json -Depth 10 | Out-File -Encoding UTF8 $tempPath
            $logBox.AppendText("Arquivo temporário criado: $tempPath`r`n")
            $logBox.AppendText("Executando comando Azure CLI...`r`n")
            $job = Start-Job -ScriptBlock {
                param($AccountName, $ResourceGroupName, $tempPath)
                & az cosmosdb mongodb user definition create --account-name $AccountName --resource-group $ResourceGroupName --body "@$tempPath" 2>&1
            } -ArgumentList $AccountName, $ResourceGroupName, $tempPath

            Wait-Job $job
            $output = Receive-Job $job
            Remove-Job $job
            Remove-Item $tempPath

            $logBox.AppendText(($output -join "`r`n") + "`r`n")
            if ($output -like '*error*' -or $output -like '*Error*') {
                $logBox.AppendText("Erro ao atualizar usuário!`r`n")
                [System.Windows.Forms.MessageBox]::Show("Erro ao atualizar usuário. Veja o log para detalhes.", "Erro", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Error)
            } else {
                $logBox.AppendText("Usuário atualizado com sucesso!`r`n")
                [System.Windows.Forms.MessageBox]::Show("Usuário atualizado com sucesso!", "Sucesso", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Information)
                $form.Close()
            }
            $logForm.Close()
        } else {
            [System.Windows.Forms.MessageBox]::Show("Preencha todos os campos.", "Erro", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Warning)
        }
    })

    $form.ShowDialog()
}

$accounts = Get-CosmosDBAccounts
if (-not $accounts) {
    [System.Windows.Forms.MessageBox]::Show("Nenhuma conta MongoDB encontrada.", "Aviso", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Warning)
    return
}

$accountOptions = $accounts | ForEach-Object { "$($_.name) [$($_.resourceGroup)]" }
$selected = $null
if ($accountOptions.Count -eq 1) {
    $selected = 0
} else {
    $selectionForm = New-Object System.Windows.Forms.Form
    $selectionForm.Text = "Selecione a Conta MongoDB"
    $selectionForm.Size = New-Object System.Drawing.Size(900, 700)
    $selectionForm.StartPosition = "CenterScreen"
    $selectionForm.Font = New-Object System.Drawing.Font("Segoe UI", 16)

    $combo = New-Object System.Windows.Forms.ComboBox
    $combo.Location = New-Object System.Drawing.Point(100,200)
    $combo.Size = New-Object System.Drawing.Size(700,60)
    $combo.Font = $selectionForm.Font
    $combo.Items.AddRange($accountOptions)
    $selectionForm.Controls.Add($combo)

    $ok = New-Object System.Windows.Forms.Button
    $ok.Text = "Selecionar"
    $ok.Location = New-Object System.Drawing.Point(350,350)
    $ok.Size = New-Object System.Drawing.Size(200,60)
    $ok.Font = $selectionForm.Font
    $ok.Add_Click({
        if ($combo.SelectedIndex -ne -1) {
            $script:selected = $combo.SelectedIndex
            $selectionForm.Close()
        }
    })
    $selectionForm.Controls.Add($ok)

    $selectionForm.ShowDialog() | Out-Null
}

if ($null -ne $selected) {
    $account = $accounts[$selected]
    while ($true) {
        $opcao = Show-MainMenuForm -AccountName $account.name -ResourceGroupName $account.resourceGroup
        switch ($opcao) {
            "Criar usuários" { Show-CreateUserForm -AccountName $account.name -ResourceGroupName $account.resourceGroup }
            "Listar usuários" { Show-ListUsersForm -AccountName $account.name -ResourceGroupName $account.resourceGroup }
            "Atualizar usuários" { Show-UpdateUserForm -AccountName $account.name -ResourceGroupName $account.resourceGroup }
            "Deletar usuários" { Show-RemoveUserForm -AccountName $account.name -ResourceGroupName $account.resourceGroup }
            "Listar permissões" { Show-ListPermissionsForm }
        }
    }
} 