# Autor: Ramon Rodrigues
# Repositorio: https://github.com/git-ramon/Limpeza-Perfil
# Contato: ramonrodriguesnw@gmail.com

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

# Junta tudo
$todos = $profileList + $orfasList

# Exibe Perfis
Write-Host ""
Write-Host "=== PERFIS ENCONTRADOS ===" -ForegroundColor Green
Write-Host ""

$todos | Select-Object Usuario, "Ultimo Uso", Tipo | Format-Table -AutoSize

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
            <#if ($perfil.Tipo -eq "Perfil") {
                $perfil.Ref | Remove-CimInstance
                Write-Host "[$i/$total] Removido perfil: $($perfil.Usuario)" -ForegroundColor Green
            } else {
                Remove-Item $perfil.Caminho -Recurse -Force
                Write-Host "[$i/$total] Removido orfao: $($perfil.Usuario)" -ForegroundColor Green
            }#>

            if ($perfil.Tipo -eq "Perfil") {
                $perfil.Ref | Remove-CimInstance -ErrorAction Stop
                Write-Host "[$i/$total] Removido perfil: $($perfil.Usuario)" -ForegroundColor Green
            } else {
                # Força permissao antes de excluir
                takeown /F $perfil.Caminho /R /D Y | Out-Null
                icacls $perfil.Caminho /grant Administradores:F /T /C | Out-Null

                # Remove pasta de forma agressiva
                cmd /c "rd /s /q `"$($perfil.Caminho)`""

                Write-Host "[$i/$total] Removido orfao: $($perfil.Usuario)" -ForegroundColor Green
            }

            Escrever-Log -Usuario $perfil.Usuario -Tipo $perfil.Tipo -Status "Sucesso"

        } catch {
            Write-Host "[$i/$total] Erro ao remover: $($perfil.Usuario)" -ForegroundColor Red

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
        Write-Host "Operacao cancelada"
    }

    Write-Host ""
    Write-Host "Finalizado!" -ForegroundColor Cyan
    Write-Host "" 
    Read-Host "Pressione ENTER para sair"