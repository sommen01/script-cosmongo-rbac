function Get-CosmosDBAccounts {
    try {
        Write-Host "`nBuscando contas CosmosDB MongoDB..."
        $accountsRaw = az cosmosdb list --query "[?capabilities[?name=='EnableMongo']]" -o json
        $accounts = $accountsRaw | ConvertFrom-Json
        Write-Host "Contas encontradas: $($accounts.Count)"
        return $accounts
    }
    catch {
        Write-Host "`nErro ao buscar contas CosmosDB:"
        Write-Host "Tipo de erro: $($_.Exception.GetType().FullName)"
        Write-Host "Mensagem: $($_.Exception.Message)"
        Write-Host "Stack Trace:`n$($_.ScriptStackTrace)"
        return @()
    }
}

function Main-Menu {
    while ($true) {
        $cosmosAccounts = Get-CosmosDBAccounts

        if (!$cosmosAccounts -or $cosmosAccounts.Count -eq 0) {
            Write-Host "Nenhuma conta CosmosDB MongoDB encontrada."
            break
        }

        $i = 1
        foreach ($account in $cosmosAccounts) {
            Write-Host "[$i] $($account.name)"
            $i++
        }
        Write-Host "[0] Sair"

        $accountChoice = Read-Host "`nEscolha a Conta (Digite o número)"
        Write-Host "Você escolheu: $accountChoice"

        if ($accountChoice -eq '0') {
            Write-Host "`nSaindo do script."
            break
        }

        try {
            $accountChoiceInt = [int]$accountChoice
            Write-Host "Conversão bem-sucedida para inteiro: $accountChoiceInt"

            if ($accountChoiceInt -gt 0 -and $accountChoiceInt -le $cosmosAccounts.Count) {
                $selectedAccount = $cosmosAccounts[$accountChoiceInt - 1]
                Write-Host "`nConta selecionada: $($selectedAccount.name)`n"
                Submenu-Account $selectedAccount
            }
            else {
                Write-Host "`nEscolha inválida. Tente novamente.`n"
            }
        }
        catch {
            Write-Host "`nErro ao processar a escolha:"
            Write-Host "Tipo de erro: $($_.Exception.GetType().FullName)"
            Write-Host "Mensagem: $($_.Exception.Message)"
            Write-Host "Stack Trace:`n$($_.ScriptStackTrace)"
        }
    }
}

function Submenu-Account {
    param($account)

    while ($true) {
        Write-Host "`nGerenciar Conta: $($account.name)"
        Write-Host "[1] Listar usuários"
        Write-Host "[2] Adicionar usuário"
        Write-Host "[3] Listar permissões"
        Write-Host "[4] Adicionar permissão"
        Write-Host "[5] Deletar usuário"
        Write-Host "[6] Deletar permissão"
        Write-Host "[0] Voltar para lista de contas"

        $action = Read-Host "`nEscolha uma ação"
        Write-Host "Você escolheu a ação: $action"

        switch ($action) {
            '0' { return } 
            '1' { Listar-Usuarios $account }
            '2' { Adicionar-Usuario $account }
            '3' { Listar-Permissoes $account }
            '4' { Adicionar-Permissao $account }
            '5' { Deletar-Usuario $account }
            '6' { Deletar-Permissao $account }
            default { Write-Host "`nOpção inválida. Tente novamente.`n" }
        }
    }
}

function Listar-Usuarios {
    param($account)
    try {
        Write-Host "`nListando usuários para a conta: $($account.name)..."
        az cosmosdb mongodb user definition list --account-name $account.name --resource-group $account.resourceGroup -o table
    }
    catch {
        Write-Host "`nErro ao listar usuários:"
        Write-Host "Tipo de erro: $($_.Exception.GetType().FullName)"
        Write-Host "Mensagem: $($_.Exception.Message)"
        Write-Host "Stack Trace:`n$($_.ScriptStackTrace)"
    }
}

function Adicionar-Usuario {
    param($account)
    try {
        $dbName = Read-Host "Nome do Banco de Dados"
        $userName = Read-Host "Nome do Usuário"
        $password = Read-Host "Senha"
        $role = Read-Host "Papel (Ex: readWrite)"

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

        Write-Host "`nUsuário adicionado com sucesso."
    }
    catch {
        Write-Host "`nErro ao adicionar usuário:"
        Write-Host "Tipo de erro: $($_.Exception.GetType().FullName)"
        Write-Host "Mensagem: $($_.Exception.Message)"
        Write-Host "Stack Trace:`n$($_.ScriptStackTrace)"
    }
}


function Listar-Permissoes {
    param($account)
    try {
        Write-Host "`nListando permissões para a conta: $($account.name)..."
        Write-Host "OBS: Permissões estão embutidas nos usuários (Roles)."
        $users = az cosmosdb mongodb user definition list --account-name $account.name --resource-group $account.resourceGroup | ConvertFrom-Json
        foreach ($user in $users) {
            Write-Host "`nUsuário: $($user.UserName)"
            foreach ($role in $user.Roles) {
                Write-Host " - Banco: $($role.Db) | Papel: $($role.Role)"
            }
        }
    }
    catch {
        Write-Host "`nErro ao listar permissões:"
        Write-Host "Tipo de erro: $($_.Exception.GetType().FullName)"
        Write-Host "Mensagem: $($_.Exception.Message)"
        Write-Host "Stack Trace:`n$($_.ScriptStackTrace)"
    }
}

function Adicionar-Permissao {
    param($account)
    Write-Host "`nPara adicionar permissão, edite o usuário manualmente (recriar)."
}

function Deletar-Usuario {
    param($account)
    try {
        $id = Read-Host "ID do usuário (Ex: Banco.Usuario)"
        az cosmosdb mongodb user definition delete `
            --account-name $account.name `
            --resource-group $account.resourceGroup `
            --ids $id

        Write-Host "`nUsuário deletado com sucesso."
    }
    catch {
        Write-Host "`nErro ao deletar usuário:"
        Write-Host "Tipo de erro: $($_.Exception.GetType().FullName)"
        Write-Host "Mensagem: $($_.Exception.Message)"
        Write-Host "Stack Trace:`n$($_.ScriptStackTrace)"
    }
}

function Deletar-Permissao {
    param($account)
    Write-Host "`nPara deletar permissão, é necessário recriar o usuário."
}

Main-Menu
