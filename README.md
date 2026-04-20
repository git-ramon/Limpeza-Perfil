# Limpeza-Perfil

Script em PowerShell para automatizar a limpeza de perfis de usuários em sistemas Windows, incluindo remoção de registros e pastas órfãs.

---

## 📌 Funcionalidades

O script realiza:

🔹 Listagem de todos os perfis em `C:\Users`  
🔹 Identificação de perfis registrados no sistema  
🔹 Identificação de pastas órfãs (sem registro)  
🔹 Identificação de registros órfãos (sem pasta)  
🔹 Remoção segura com confirmação do usuário  
🔹 Execução local ou remota (via nome ou IP)  
🔹 Execução silenciosa (remoto)  
🔹 Registro de log detalhado  

---

## 📝 Log de Execução

O script gera automaticamente um arquivo de log contendo:

- Usuário removido  
- Data e hora da execução  
- Usuário que executou o script  
- Nome da máquina  

📁 Caminho padrão do log: C:\Log\Limpeza_perfis.txt

---

## 🌐 Execução Remota

O script permite executar a limpeza em máquinas remotas informando:

Nome da máquina
Endereço IP

---

---
## Executável (.exe)

O projeto inclui opção para versão compilada via Win-PS2EXE:

✔ Execução sem necessidade de abrir PowerShell
✔ Ideal para uso em suporte técnico
✔ Portátil (pode rodar em outras máquinas)
---

## ▶️ Como usar

1. Execute o script com PowerShell e privilégios de administrador;
2. Informe os usuários que deseja manter (separados por vírgula)
3. Revise a lista de perfis que serão removidos
4. Confirme a exclusão

⚠️ Atenção

- Revise cuidadosamente os usuários antes de confirmar
- Perfis ativos não devem ser removidos
- A exclusão é permanente

---

Testes:

O repositório inclui um script auxiliar para:

- Criação de usuários de teste
- Simulação de perfis e pastas órfãs

---

👨‍💻 Autor:

Ramon Rodrigues   
📧 ramonrodriguesnw@gmail.com  
🔗 https://github.com/git-ramon/Limpeza-Perfil  

---

📄 Licença

Uso livre para fins educacionais e corporativos.

---

## Contribuição

Contribuições são bem-vindas!  
Sinta-se à vontade para abrir issues, sugerir melhorias ou enviar um pull request.