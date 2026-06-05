# Autor: Ramon Rodrigues
# Repositorio: https://github.com/git-ramon/Limpeza-Perfil
# Contato: ramonrodriguesnw@gmail.com

function Escrever-Log-Remoto {
    param(
        [string]$Usuario,
        [string]$Tipo,
        [string]$Status,
        [string]$Computador
    )

    $pastaLog = "\\$Computador\c$\Temp"

    # cria pasta se não existir
    if (-not (Test-Path $pastaLog)) {
        New-Item -Path $pastaLog -ItemType Directory | Out-Null
    }

    $logPath = "$pastaLog\log_$Computador.txt"

    $data = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $linha = "$data | $Usuario | $Tipo | $Status"

    Add-Content -Path $logPath -Value $linha
}

function Executar-Limpeza {

param(
    [string]$Modo,
    [string]$Manter,
    [string]$Confirmar,
    [string]$ArquivoSaida
)

$scriptPath = $MyInvocation.MyCommand.Path

#diretório do log de registro
$logPath = "C:\Log\limpeza_perfis.log"

# cria pasta se nao existir
if (-not (Test-Path "C:\Log")) {
    New-Item -Path "C:\Log" -ItemType Directory | Out-Null
}

    # Log de registro
    function Escrever-Log {
        param (
            $Usuario,
            $Tipo,
            $Status
        )

        $data = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
        $executadoPor = $env:USERNAME
        $maquina = $env:COMPUTERNAME

        $linha = "$data | UsuarioRemovido: $Usuario | Tipo: $Tipo | Status: $Status | ExecutadoPor: $executadoPor | Maquina: $maquina"

        Add-Content -Path $logPath -Value $linha
    }

# Lista perfis
$profiles = Get-CimInstance Win32_UserProfile | Where-Object {
    $_.LocalPath -like "C:\Users\*" -and
    -not $_.Special
}

# Monta lista de perfis validos
$profileList = $profiles | ForEach-Object {
    [PSCustomObject]@{
        Usuario = Split-Path $_.LocalPath -Leaf
        #"Ultimo Uso" = if ($_.LastUseTime) { $_.LastUseTime } else { "Desconhecido" }

        "Ultimo Uso" = if (Test-Path $_.LocalPath) { (Get-Item $_.LocalPath).LastWriteTime } else { "Desconhecido" }

        Tipo = "Perfil"
        Ref = $_
        Caminho = $_.LocalPath
    }
}

# Detecta pastas orfas
$pastas = Get-ChildItem "C:\Users" -Directory
$caminhosValidos = $profiles | Select-Object -ExpandProperty LocalPath

$orfas = $pastas | Where-Object {
    $_.FullName -notin $caminhosValidos -and
    $_.Name -notin @("Public","Default","Default User","All Users","Administrador")
}

# Monta lista de orfas
$orfasList = $orfas | ForEach-Object {
    [PSCustomObject]@{
        Usuario = $_.Name
        "Ultimo Uso" = "Orfao"
        Tipo = "Orfao"
        Ref = $null
        Caminho = $_.FullName
    }
}

# Detecta REGISTROS órfãos (tem no CIM mas NÃO existe pasta)
$profileList = $profiles | ForEach-Object {

    $existePasta = Test-Path $_.LocalPath

    [PSCustomObject]@{
        Usuario = Split-Path $_.LocalPath -Leaf

        "Ultimo Uso" = if ($existePasta) { 
            (Get-Item $_.LocalPath).LastWriteTime 
        } else { 
            "OrfaoRegistro"
        }

        Tipo = if ($existePasta) { 
            "Perfil" 
        } else { 
            "OrfaoRegistro" 
        }

        Ref = $_
        Caminho = $_.LocalPath
    }
}

# Junta tudo
#$todos = $profileList + $orfasList
$todos = @($profileList) + @($orfasList)

# Inicio da função que calcula espaço em disco local

    try {
        Write-Host ""
        Write-Host "=== ESPACO EM DISCO ===" -ForegroundColor Cyan

        Get-PSDrive -PSProvider FileSystem | Select-Object `
            @{Name="Disco";Expression={$_.Name}},
            @{Name="Total(GB)";Expression={[math]::Round(($_.Used + $_.Free)/1GB,2)}},
            @{Name="Livre(GB)";Expression={[math]::Round($_.Free/1GB,2)}} |
        Format-Table -AutoSize

    } catch {
        Write-Host ""
        Write-Host "Falha ao consultar espaco em disco local." -ForegroundColor Red
        Write-Host ""
    }

# Fim da função que calcula espaço em disco local


# Exibe Perfis
Write-Host ""
Write-Host "=== PERFIS ENCONTRADOS ===" -ForegroundColor Green
Write-Host ""

$todos | Select-Object Usuario, "Ultimo Uso", Tipo | Format-Table -AutoSize

if ($erroPath) {
    Write-Host ""
    Write-Host "Aviso: Alguns perfis foram ignorados devido a inconsistências." -ForegroundColor Yellow
    Write-Host ""
}

# Input para entrada de usuário
$manter = Read-Host "Digite os usuarios que deseja manter (separados por virgula)"
$manterLista = $manter -split "," | ForEach-Object { $_.Trim() }

# Filtra
$remover = $todos | Where-Object {
    $_.Usuario -notin $manterLista
}

# Mostra remocao
Write-Host ""
Write-Host "=== PERFIS QUE SERAO REMOVIDOS ===" -ForegroundColor Red
Write-Host ""

$remover | Select-Object Usuario, "Ultimo Uso", Tipo | Format-Table -AutoSize

$confirm = Read-Host "Confirma remocao? S ou N"

if ($confirm -eq "S") {
    $total = $remover.Count
    $i = 0

    Write-Host ""
    Write-Host "Iniciando remocao..." -ForegroundColor Cyan
    
    # Reservamos uma linha vazia para a barra e guardamos a posição
    Write-Host "" 
    $posicaoBarra = [Console]::CursorTop
    Write-Host "" # Espaço extra para não sobrescrever o final do console

    foreach ($perfil in $remover) {
        $i++
        
        # 1. Move o cursor para cima da barra para escrever o log do arquivo atual
        [Console]::SetCursorPosition(0, $posicaoBarra)
        
        try {
            if ($perfil.Tipo -eq "Perfil") {

                $perfil.Ref | Remove-CimInstance -ErrorAction Stop
                Write-Host "[$i/$total] Removido perfil: $($perfil.Usuario)" -ForegroundColor Green

            }elseif ($perfil.Tipo -eq "OrfaoRegistro") {

                $perfil.Ref | Remove-CimInstance -ErrorAction Stop
                Write-Host "[$i/$total] Removido registro orfao: $($perfil.Usuario)" -ForegroundColor Magenta

            } else {

                # Assume posse
                takeown /F $perfil.Caminho /R /D Y > $null 2>&1

                # Garante permissão total
                icacls $perfil.Caminho /grant Administradores:F /T /C > $null 2>&1

                # Remove atributos protegidos
                attrib -h -r -s "$($perfil.Caminho)" /S /D > $null 2>&1

                # Tentativa principal (não quebra tudo)
                Remove-Item $perfil.Caminho -Recurse -Force -ErrorAction SilentlyContinue

                # Se ainda existir, usa fallback pesado
                if (Test-Path $perfil.Caminho) {
                    cmd /c "rd /s /q `"$($perfil.Caminho)`"" > $null 2>&1
                }

                Write-Host "[$i/$total] Removido orfao: $($perfil.Usuario)" -ForegroundColor Yellow

            }

            Escrever-Log -Usuario $perfil.Usuario -Tipo $perfil.Tipo -Status "Sucesso"

        }
        catch {
            Write-Host "[$i/$total] Erro ao remover perfil local: $($perfil.Usuario)" -ForegroundColor Red
            Write-Host $_.Exception.Message -ForegroundColor Yellow

            Escrever-Log -Usuario $perfil.Usuario -Tipo $perfil.Tipo -Status $_.Exception.Message
        }

        # Atualiza a posição da barra (caso a lista de logs tenha crescido)
        $posicaoBarra = [Console]::CursorTop

        # 2. Calcula e desenha a barra de progresso logo abaixo do último log
        # $percent = [int](($i / $total) * 100)
        $percent = if ($total -gt 0) { [int](($i / $total) * 100) } else { 100 }
        $bars = [int]($percent / 5)
        $barra = ("=" * $bars).PadRight(20, " ")

    }
        Write-Host "" 
        Write-Host "`rProgresso: [$barra] $percent%" -ForegroundColor Green -NoNewline
        Write-Host "" # Quebra de linha final

    } else {
        Write-Host "" 
        Write-Host "Operacao cancelada"
    }

    Write-Host ""
    Write-Host "Finalizado!" -ForegroundColor Cyan
    Write-Host "" 
    Read-Host "Pressione ENTER para sair"

}



### Menu do Script para incluir Limpeza de Perfil Remota ###

Write-Host ""
Write-Host "=== TIPO DE LIMPEZA ===" -ForegroundColor Cyan
Write-Host ""
Write-Host "1 - ACESSO LOCAL"
Write-Host "2 - ACESSO REMOTO"
Write-Host ""

$opcao = Read-Host "DIGITE A OPCAO"
Write-Host ""

if ($opcao -ne "1" -and $opcao -ne "2") {
    Write-Host "Opcao incorreta!" -ForegroundColor Red
    Write-Host ""
    Read-Host "Pressione ENTER para sair"
    return
}

if ($opcao -eq "1") {
    Executar-Limpeza
}
elseif ($opcao -eq "2") {

    $computador = Read-Host "Digite o nome ou IP da maquina"
    Write-Host ""

    # Inicio da função que calcula espaço em disco Remoto
        # Detecta IP 
        $ehIP = $computador -match '^\d{1,3}(\.\d{1,3}){3}$' 
        
        if ($ehIP) { try { 
            # tenta resolver hostname 
            $hostname = [System.Net.Dns]::GetHostEntry($computador).HostName 
            
            if ($hostname) { 
                $computador = $hostname 
                } 
            } catch { 
                # fallback TrustedHosts 
                Set-Item 
                -Path WSMan:\localhost\Client\TrustedHosts 
                -Value "$computador" 
                -Force 
                } 
            } 
        
        try {
            $resultado = Get-CimInstance `
                -ClassName Win32_LogicalDisk `
                -ComputerName $computador `
                -Filter "DriveType=3" `
                -ErrorAction Stop | 
            Select-Object `
                @{Name="Disco";Expression={$_.DeviceID}}, 
                @{Name="Total(GB)";Expression={[math]::Round($_.Size/1GB,2)}}, 
                @{Name="Livre(GB)";Expression={[math]::Round($_.FreeSpace/1GB,2)}} 
                
            Write-Host "" 
            Write-Host "=== ESPACO EM DISCO ===" -ForegroundColor Cyan
            Write-Host "" 

            $resultado | Format-Table -AutoSize | Out-String | Write-Host
            } 
            
            catch { 
                
                if ($_.Exception.Message -like "*Access is denied*") { 
                    Write-Host "" Write-Host "Acesso negado." -ForegroundColor Red 
                    Write-Host "" 
                } else { 
                    Write-Host "" 
                    Write-Host "Falha ao consultar espaco em disco." -ForegroundColor Red 
                    Write-Host "" 
                } 
            }

    # Fim da função que calcula espaço em disco Remoto

    if (-not (Test-Connection -ComputerName $computador -Count 1 -Quiet)) {
        Write-Host "Maquina nao encontrada!" -ForegroundColor Red
        Write-Host ""
        Read-Host "Pressione ENTER para sair"
        return
    }

    #$perfisCIM = Get-CimInstance Win32_UserProfile -ComputerName $computador

    $perfisCIM = $null

    # 1. Tenta via WinRM (padrão - funciona por nome)
    try {
        $perfisCIM = Get-CimInstance Win32_UserProfile -ComputerName $computador -ErrorAction Stop
    }
    catch {
        Write-Host "WinRM falhou. Tentando via DCOM..." -ForegroundColor Yellow
        Write-Host ""

        # 2. Fallback via DCOM (funciona por IP)
        try {
            $session = New-CimSession -ComputerName $computador -SessionOption (New-CimSessionOption -Protocol Dcom) -ErrorAction Stop
            $perfisCIM = Get-CimInstance Win32_UserProfile -CimSession $session -ErrorAction Stop
        }
        catch {
            Write-Host "Aviso: Nao foi possivel obter perfis via CIM (WinRM/DCOM)." -ForegroundColor Red
            Write-Host ""
            $perfisCIM = $null
        }
    }

    $caminhoUsuarios = "\\$computador\c$\Users"

if (-not (Test-Path $caminhoUsuarios)) {
    Write-Host "Nao foi possivel acessar o caminho remoto!" -ForegroundColor Red
    Write-Host ""
    Read-Host "Pressione ENTER para sair"
    return
}

Write-Host ""
Write-Host "=== PERFIS ENCONTRADOS ===" -ForegroundColor Green
Write-Host ""

$usuarios = Get-ChildItem -Path $caminhoUsuarios -Directory -ErrorAction SilentlyContinue

if (-not $usuarios) {
    Write-Host "Nenhum perfil encontrado ou acesso negado." -ForegroundColor Yellow
    Write-Host ""
    Read-Host "Pressione ENTER para sair"
    return
}

$resultado = @()

# Perfis com pasta
foreach ($user in $usuarios) {

    if ($user.Name -in @("Public", "Default", "Default User", "All Users", "systemprofile","LocalService","NetworkService",
    "DefaultAppPool","WDAGUtilityAccount","ksnproxy")) {
        continue
    }

    $perfilCIM = $perfisCIM | Where-Object {
        $_.LocalPath -like "*\$($user.Name)"
    }

    $resultado += [PSCustomObject]@{
        Usuario      = $user.Name
        "Ultimo Uso" = $user.LastWriteTime
        Tipo         = if ($perfilCIM) { "Perfil" } else { "OrfaoDisco" }
    }
}

$erroPath = $false

# Perfis órfãos de registro (sem pasta)
foreach ($perfil in $perfisCIM) {

    #$nome = Split-Path ($perfil.LocalPath -as [string]) -Leaf
    try {
    $nome = Split-Path $perfil.LocalPath -Leaf
        }
        catch {
            $erroPath = $true
            continue
        }

    if ($nome -in @("Public", "Default", "Default User", "All Users", "systemprofile","LocalService","NetworkService",
    "DefaultAppPool","WDAGUtilityAccount","ksnproxy")) {
        continue
    }

    $existePasta = $usuarios | Where-Object { $_.Name -eq $nome }

    if (-not $existePasta) {
        $resultado += [PSCustomObject]@{
            Usuario      = $nome
            "Ultimo Uso" = if ($perfil.LastUseTime) { $perfil.LastUseTime } else { "Desconhecido" }
            Tipo         = "OrfaoRegistro"
        }
    }
}

if ($resultado) {
    $resultado | Format-Table -AutoSize
} else {
    Write-Host ""
    Write-Host "Nenhum perfil valido encontrado apos filtro." -ForegroundColor Yellow
    Write-Host ""
}

    $todos | Select-Object Usuario, "Ultimo Uso", Tipo | Format-Table -AutoSize

    # Input para entrada de usuário
    $manter = Read-Host "Digite os usuarios que deseja manter (separados por virgula)"

    # Converte em array e remove espaços
    $usuariosManter = $manter -split "," | ForEach-Object { $_.Trim() }

    # Filtra quem será removido
    $usuariosRemover = $resultado | Where-Object {
        $usuariosManter -notcontains $_.Usuario
    }

    # Mostra remocao
    Write-Host ""
    Write-Host "=== PERFIS QUE SERAO REMOVIDOS ===" -ForegroundColor Red
    Write-Host ""

    if ($usuariosRemover) {
        $usuariosRemover | Format-Table -AutoSize
    } else {
        Write-Host "Nenhum perfil para remover." -ForegroundColor Green
    }

    $confirm = Read-Host "Confirmar remocao? S ou N"

if ($confirm -eq "S") {
    $total = $usuariosRemover.Count
    $i = 0

    Write-Host ""
    Write-Host "Iniciando remocao..." -ForegroundColor Cyan
    
    # Reservamos uma linha vazia para a barra e guardamos a posição
    Write-Host "" 
    $posicaoBarra = [Console]::CursorTop
    Write-Host "" # Espaço extra para não sobrescrever o final do console

    foreach ($perfil in $usuariosRemover) {
        $i++
        
        # 1. Move o cursor para cima da barra para escrever o log do arquivo atual
        [Console]::SetCursorPosition(0, $posicaoBarra)
        
        try {
            if (-not $perfisCIM) {
                $query = quser /server:$computador 2>$null

                if ($query) {
                    # Extrai apenas os nomes dos usuários logados
                    $usuariosLogados = ($query | Select-Object -Skip 1) | ForEach-Object {
                        ($_ -replace '^\s*>?\s*', '').Split(' ', [System.StringSplitOptions]::RemoveEmptyEntries)[0]
                    }

                    if ($usuariosLogados -contains $perfil.Usuario) {
                        throw "0x80070020 - Perfil em uso"
                    }
                }
            }

            $perfilCIM = $perfisCIM | Where-Object {
                $_.LocalPath -like "*\$($perfil.Usuario)"
            }

            if ($perfil.Tipo -eq "Perfil") {
                Remove-CimInstance -InputObject $perfilCIM -ErrorAction Stop
                Write-Host "[$i/$total] Removido perfil completo: $($perfil.Usuario)" -ForegroundColor Green
            }
            elseif ($perfil.Tipo -eq "OrfaoDisco") {
                $caminhoPerfil = "\\$computador\c$\Users\$($perfil.Usuario)"

                takeown /F $caminhoPerfil /R /D Y > $null 2>&1
                icacls $caminhoPerfil /grant Administradores:F /T /C > $null 2>&1
                cmd /c "rd /s /q `"$caminhoPerfil`"" > $null 2>&1

                Write-Host "[$i/$total] Removido pasta Orfa: $($perfil.Usuario)" -ForegroundColor Yellow

            }
            elseif ($perfil.Tipo -eq "OrfaoRegistro") {
                Remove-CimInstance -InputObject $perfilCIM -ErrorAction Stop
                Write-Host "[$i/$total] Removido registro Orfao: $($perfil.Usuario)" -ForegroundColor Magenta
            }

            Escrever-Log-Remoto -Usuario $perfil.Usuario -Tipo $perfil.Tipo -Status "Sucesso" -Computador $computador

        } catch {
            Write-Host "[$i/$total] Erro ao remover Perfil Remoto: $($perfil.Usuario)" -ForegroundColor Red
            
            if ($_.Exception.Message -match "0x80070020") {
                Write-Host "Perfil Remoto em uso por outro processo" -ForegroundColor Yellow
            } else {
                Write-Host $_.Exception.Message -ForegroundColor Yellow
            }

            Escrever-Log-Remoto -Usuario $perfil.Usuario -Tipo $perfil.Tipo -Status $_.Exception.Message -Computador $computador
        }

        # Atualiza a posição da barra (caso a lista de logs tenha crescido)
        $posicaoBarra = [Console]::CursorTop

        # 2. Desenha a barra de progresso logo abaixo do último log
        $percent = if ($total -gt 0) { [int](($i / $total) * 100) } else { 100 }
        $bars = [int]($percent / 5)
        $barra = ("=" * $bars).PadRight(20, " ")

    }
        Write-Host "" 
        Write-Host "`rProgresso: [$barra] $percent%" -ForegroundColor Green -NoNewline
        Write-Host "" # Quebra de linha final

    } else {
        Write-Host "" 
        Write-Host "Operacao cancelada"
    }

    Write-Host ""
    Write-Host "Finalizado!" -ForegroundColor Cyan
    Write-Host "" 
    Read-Host "Pressione ENTER para sair"
}

   

### Fim do Menu do Script para incluir Limpeza de Perfil Remota ###