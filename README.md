### Script automatizado
```
curl -fsSL [https://raw.githubusercontent.com/WhoFoss/build-los/refs/heads/main/compile.sh](https://raw.githubusercontent.com/WhoFoss/Build-LineageOS-MicroG/refs/heads/main/run.sh) | bash
```

### Gofile upload
```
curl -s https://raw.githubusercontent.com/saroj-nokia/GoFile-Upload/refs/heads/master/upload.sh | bash -s -- /path/to/your/file.zip
```
---
> Observações: Não é necessário criar uma pasta para executar o script, pois o mesmo já faz isso automaticamente. Apenas execute-o em qualquer local e ele criará a pasta `LineageOS-MicroG` automaticamente para dar início ao trabalho de compilação automatizada.
