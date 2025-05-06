function Adicionar-Usuario {
    param($account)

    Add-Type -AssemblyName System.Windows.Forms
    Add-Type -AssemblyName System.Drawing

    $mongoRoles = @("read", "readWrite", "dbAdmin", "dbOwner", "userAdmin", "clusterAdmin", "readAnyDatabase", "readWriteAnyDatabase", "userAdminAnyDatabase", "dbAdminAnyDatabase")

    $databasesRaw = az cosmosdb mongodb database list `
        --account-name $account.name `
        --resource-group $account.resourceGroup `
        --query "[].name" -o json

    $databases = $databasesRaw | ConvertFrom-Json

    if (!$databases -or $databases.Count -eq 0) {
        [System.Windows.Forms.MessageBox]::Show("Nenhum banco de dados encontrado.", "Erro", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Error)
        return
    }

    $form = New-Object System.Windows.Forms.Form
    $form.Text = "Adicionar Usuário MongoDB"
    $form.Size = New-Object System.Drawing.Size(400,300)
    $form.StartPosition = "CenterScreen"

    $labelDb = New-Object System.Windows.Forms.Label
    $labelDb.Text = "Banco de Dados:"
    $labelDb.Location = New-Object System.Drawing.Point(10,20)
    $labelDb.Size = New-Object System.Drawing.Size(120,20)
    $form.Controls.Add($labelDb)

    $comboDb = New-Object System.Windows.Forms.ComboBox
    $comboDb.Location = New-Object System.Drawing.Point(150,18)
    $comboDb.Size = New-Object System.Drawing.Size(200,20)
    $comboDb.Items.AddRange($databases)
    $comboDb.SelectedIndex = 0
    $form.Controls.Add($comboDb)

    $labelUser = New-Object System.Windows.Forms.Label
    $labelUser.Text = "Nome do Usuário:"
    $labelUser.Location = New-Object System.Drawing.Point(10,60)
    $labelUser.Size = New-Object System.Drawing.Size(120,20)
    $form.Controls.Add($labelUser)

    $textUser = New-Object System.Windows.Forms.TextBox
    $textUser.Location = New-Object System.Drawing.Point(150,58)
    $textUser.Size = New-Object System.Drawing.Size(200,20)
    $form.Controls.Add($textUser)

    $labelPass = New-Object System.Windows.Forms.Label
    $labelPass.Text = "Senha:"
    $labelPass.Location = New-Object System.Drawing.Point(10,100)
    $labelPass.Size = New-Object System.Drawing.Size(120,20)
    $form.Controls.Add($labelPass)

    $textPass = New-Object System.Windows.Forms.TextBox
    $textPass.Location = New-Object System.Drawing.Point(150,98)
    $textPass.Size = New-Object System.Drawing.Size(200,20)
    $textPass.UseSystemPasswordChar = $true
    $form.Controls.Add($textPass)

    $labelRole = New-Object System.Windows.Forms.Label
    $labelRole.Text = "Permissão:"
    $labelRole.Location = New-Object System.Drawing.Point(10,140)
    $labelRole.Size = New-Object System.Drawing.Size(120,20)
    $form.Controls.Add($labelRole)

    $comboRole = New-Object System.Windows.Forms.ComboBox
    $comboRole.Location = New-Object System.Drawing.Point(150,138)
    $comboRole.Size = New-Object System.Drawing.Size(200,20)
    $comboRole.Items.AddRange($mongoRoles)
    $comboRole.SelectedIndex = 1  
    $form.Controls.Add($comboRole)

    $btnOK = New-Object System.Windows.Forms.Button
    $btnOK.Text = "Criar Usuário"
    $btnOK.Location = New-Object System.Drawing.Point(150,180)
    $btnOK.Add_Click({
        $dbName = $comboDb.SelectedItem
        $userName = $textUser.Text
        $password = $textPass.Text
        $role = $comboRole.SelectedItem

        if (-not $userName -or -not $password) {
            [System.Windows.Forms.MessageBox]::Show("Preencha todos os campos.", "Aviso", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Warning)
            return
        }

        $body = @{
            Id = "$dbName.$userName"
            UserName = "$userName"
            Password = "$password"
            DatabaseName = $dbName
            CustomData = ""
            Mechanisms = "SCRAM-SHA-256"
            Roles = @(@{ Role = $role; Db = $dbName })
        }

        $tempPath = [System.IO.Path]::GetTempFileName() + ".json"
        $body | ConvertTo-Json -Depth 10 | Out-File -Encoding UTF8 $tempPath

        az cosmosdb mongodb user definition create `
            --account-name $account.name `
            --resource-group $account.resourceGroup `
            --body "@$tempPath"

        Remove-Item $tempPath

        [System.Windows.Forms.MessageBox]::Show("Usuário adicionado com sucesso.", "Sucesso", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Information)
        $form.Close()
    })
    $form.Controls.Add($btnOK)

    $form.ShowDialog()
}
