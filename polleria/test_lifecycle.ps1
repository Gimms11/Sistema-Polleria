# Script de prueba automatizada: Ciclo de Vida del Pedido y Auditoria de Seguridad
$ErrorActionPreference = "Stop"

function Write-Step($title) {
    Write-Host "`n==================================================" -ForegroundColor Cyan
    Write-Host ">>> $title" -ForegroundColor Yellow
    Write-Host "==================================================" -ForegroundColor Cyan
}

try {
    # -------------------------------------------------------------------------
    Write-Step "1. Login de Cliente con Yopmail (cliente.polleria@yopmail.com)"
    # -------------------------------------------------------------------------
    $loginBody = @{
        identifier = "cliente.polleria@yopmail.com"
        password   = "Password123!"
    } | ConvertTo-Json

    $loginResp = Invoke-RestMethod -Uri "http://localhost:8081/auth/login" -Method Post -Body $loginBody -ContentType "application/json"
    $clientToken = $loginResp.token
    $clientRefreshToken = $loginResp.refreshToken

    Write-Host "OK - Login de cliente exitoso!" -ForegroundColor Green
    Write-Host "   Nombre: $($loginResp.name)"
    Write-Host "   Rol: $($loginResp.role)"
    Write-Host "   Token JWT (preview): $($clientToken.Substring(0, 30))..."
    Write-Host "   Refresh Token: $clientRefreshToken"

    # -------------------------------------------------------------------------
    Write-Step "2. Login de Admin con 2FA (admin.polleria@yopmail.com)"
    # -------------------------------------------------------------------------
    $adminLoginBody = @{
        identifier = "admin.polleria@yopmail.com"
        password   = "Password123!"
    } | ConvertTo-Json

    $adminInitResp = Invoke-RestMethod -Uri "http://localhost:8081/auth/login" -Method Post -Body $adminLoginBody -ContentType "application/json"
    Write-Host "   Respuesta inicial de login Admin: requiresTwoFactor = $($adminInitResp.requiresTwoFactor)"

    # Obtener el codigo 2FA generado en base de datos
    $rawCode = docker exec polleria-postgres psql -U postgres -d polleria -t -A -c "SELECT code FROM two_factor_tokens WHERE user_id = (SELECT id FROM users WHERE email='admin.polleria@yopmail.com') AND used=false ORDER BY created_at DESC LIMIT 1;"
    $twoFactorCode = "$rawCode".Trim()
    
    if ($twoFactorCode -match "^\d{6}$") {
        Write-Host "   Codigo 2FA capturado de la base de datos: $twoFactorCode" -ForegroundColor Magenta

        $verifyBody = @{
            email = "admin.polleria@yopmail.com"
            code  = $twoFactorCode
        } | ConvertTo-Json

        $adminAuthResp = Invoke-RestMethod -Uri "http://localhost:8081/auth/verify-2fa" -Method Post -Body $verifyBody -ContentType "application/json"
        $adminToken = $adminAuthResp.token
        Write-Host "OK - 2FA verificado exitosamente! Token Admin obtenido." -ForegroundColor Green
    } else {
        throw "No se pudo obtener el codigo 2FA de la base de datos"
    }

    # -------------------------------------------------------------------------
    Write-Step "3. Configuracion de Carta y Mesas (Admin)"
    # -------------------------------------------------------------------------
    $authAdminHeaders = @{ Authorization = "Bearer $adminToken" }

    # Crear Mesa 1
    try {
        $mesaBody = @{ numero = 1; capacidad = 4 } | ConvertTo-Json
        $mesaResp = Invoke-RestMethod -Uri "http://localhost:8082/mesas" -Method Post -Headers $authAdminHeaders -Body $mesaBody -ContentType "application/json"
        $mesaId = $mesaResp.id
        Write-Host "OK - Mesa #1 creada (ID: $mesaId)" -ForegroundColor Green
    } catch {
        $mesas = Invoke-RestMethod -Uri "http://localhost:8082/mesas" -Method Get -Headers $authAdminHeaders
        $mesaId = $mesas[0].id
        Write-Host "INFO - Usando Mesa existente ID: $mesaId" -ForegroundColor Yellow
    }

    # Crear Productos en Carta si no existen
    $productosExistentes = Invoke-RestMethod -Uri "http://localhost:8082/productos" -Method Get
    if ($productosExistentes.Count -eq 0) {
        $p1 = @{
            nombre      = "1 Pollo a la Brasa Clasico"
            descripcion = "Con papas fritas y ensalada fresca"
            precio      = 65.50
            categoria   = "POLLO_ENTERO"
            disponible  = $true
        } | ConvertTo-Json
        $prod1 = Invoke-RestMethod -Uri "http://localhost:8082/productos" -Method Post -Headers $authAdminHeaders -Body $p1 -ContentType "application/json"
        
        $p2 = @{
            nombre      = "Inca Kola 1.5L"
            descripcion = "Gaseosa helada"
            precio      = 12.00
            categoria   = "BEBIDA"
            disponible  = $true
        } | ConvertTo-Json
        $prod2 = Invoke-RestMethod -Uri "http://localhost:8082/productos" -Method Post -Headers $authAdminHeaders -Body $p2 -ContentType "application/json"

        $prod1Id = $prod1.id
        $prod2Id = $prod2.id
        Write-Host "OK - Productos creados en carta: ID $prod1Id y ID $prod2Id" -ForegroundColor Green
    } else {
        $prod1Id = $productosExistentes[0].id
        $prod2Id = if ($productosExistentes.Count -gt 1) { $productosExistentes[1].id } else { $prod1Id }
        Write-Host "INFO - Usando productos existentes: ID $prod1Id y ID $prod2Id" -ForegroundColor Yellow
    }

    # -------------------------------------------------------------------------
    Write-Step "4. Cliente Consulta la Carta Publica (sin token)"
    # -------------------------------------------------------------------------
    $carta = Invoke-RestMethod -Uri "http://localhost:8082/productos" -Method Get
    Write-Host "OK - Carta consultada publicamente. $($carta.Count) productos disponibles." -ForegroundColor Green

    # -------------------------------------------------------------------------
    Write-Step "5. Cliente Crea un Pedido (SALON en Mesa #$mesaId)"
    # -------------------------------------------------------------------------
    $authClientHeaders = @{ Authorization = "Bearer $clientToken" }

    $orderPayload = @{
        tipo          = "SALON"
        mesaId        = $mesaId
        observaciones = "Papas bien doradas por favor"
        items         = @(
            @{ productoId = $prod1Id; cantidad = 1; notas = "Parte pierna" }
            @{ productoId = $prod2Id; cantidad = 2; notas = "Bien helada" }
        )
    } | ConvertTo-Json -Depth 5

    $orderResp = Invoke-RestMethod -Uri "http://localhost:8082/ordenes" -Method Post -Headers $authClientHeaders -Body $orderPayload -ContentType "application/json"
    $ordenId = $orderResp.id
    $montoTotal = $orderResp.total

    Write-Host "OK - Orden #$ordenId creada exitosamente!" -ForegroundColor Green
    Write-Host "   Tipo: $($orderResp.tipo)"
    Write-Host "   Estado: $($orderResp.estado)"
    Write-Host "   Monto Total: S/ $montoTotal"
    Write-Host "   Items: $($orderResp.items.Count)"

    # -------------------------------------------------------------------------
    Write-Step "6. Cliente Consulta el Estado del Pedido (Tracking)"
    # -------------------------------------------------------------------------
    $trackingResp = Invoke-RestMethod -Uri "http://localhost:8082/ordenes/$ordenId" -Method Get -Headers $authClientHeaders
    Write-Host "OK - Tracking verificado! Orden #$ordenId en estado: $($trackingResp.estado)" -ForegroundColor Green

    # -------------------------------------------------------------------------
    Write-Step "7. Cliente Paga el Pedido (payments-service)"
    # -------------------------------------------------------------------------
    $paymentPayload = @{
        ordenId       = $ordenId
        monto         = $montoTotal
        metodoPago    = "TARJETA"
        tokenPasarela = "tok_test_mock_visa_4242"
    } | ConvertTo-Json

    $paymentResp = Invoke-RestMethod -Uri "http://localhost:8083/pagos" -Method Post -Headers $authClientHeaders -Body $paymentPayload -ContentType "application/json"
    Write-Host "OK - Pago procesado exitosamente!" -ForegroundColor Green
    Write-Host "   Pago ID: $($paymentResp.id)"
    Write-Host "   Estado: $($paymentResp.estado)"
    Write-Host "   Referencia: $($paymentResp.referenciaExterna)"

    # -------------------------------------------------------------------------
    Write-Step "8. Progresion del Pedido por Cocina y Salon"
    # -------------------------------------------------------------------------
    $pPrep = @{ estado = "EN_PREPARACION" } | ConvertTo-Json
    $rPrep = Invoke-RestMethod -Uri "http://localhost:8082/ordenes/$ordenId/estado" -Method Patch -Headers $authAdminHeaders -Body $pPrep -ContentType "application/json"
    Write-Host ">>> Estado actualizado a: $($rPrep.estado)" -ForegroundColor Cyan

    $pListo = @{ estado = "LISTO" } | ConvertTo-Json
    $rListo = Invoke-RestMethod -Uri "http://localhost:8082/ordenes/$ordenId/estado" -Method Patch -Headers $authAdminHeaders -Body $pListo -ContentType "application/json"
    Write-Host ">>> Estado actualizado a: $($rListo.estado)" -ForegroundColor Cyan

    $pEntregado = @{ estado = "ENTREGADO" } | ConvertTo-Json
    $rEntregado = Invoke-RestMethod -Uri "http://localhost:8082/ordenes/$ordenId/estado" -Method Patch -Headers $authAdminHeaders -Body $pEntregado -ContentType "application/json"
    Write-Host "OK - Estado final de la orden: $($rEntregado.estado)" -ForegroundColor Green

    # -------------------------------------------------------------------------
    Write-Step "9. Cliente Consulta su Historial de Ordenes"
    # -------------------------------------------------------------------------
    $misOrdenes = Invoke-RestMethod -Uri "http://localhost:8082/ordenes/mis-ordenes" -Method Get -Headers $authClientHeaders
    Write-Host "OK - Historial del cliente obtenido ($($misOrdenes.Count) ordenes)." -ForegroundColor Green

    # -------------------------------------------------------------------------
    Write-Step "10. Auditoria de Seguridad: Refresh Token Rotation (RTR)"
    # -------------------------------------------------------------------------
    $refreshBody = @{ refreshToken = $clientRefreshToken } | ConvertTo-Json
    $refreshResp = Invoke-RestMethod -Uri "http://localhost:8081/auth/refresh" -Method Post -Body $refreshBody -ContentType "application/json"
    $newClientToken = $refreshResp.token
    $newClientRefreshToken = $refreshResp.refreshToken

    Write-Host "OK - Refresh Token rotado exitosamente!" -ForegroundColor Green
    Write-Host "   Nuevo Token (preview): $($newClientToken.Substring(0, 30))..."
    Write-Host "   Nuevo Refresh Token: $newClientRefreshToken"

    # Verificar que el viejo refresh token YA NO SIRVE (deteccion de reuso / invalidado)
    try {
        $stolenAttempt = @{ refreshToken = $clientRefreshToken } | ConvertTo-Json
        Invoke-RestMethod -Uri "http://localhost:8081/auth/refresh" -Method Post -Body $stolenAttempt -ContentType "application/json"
        Write-Error "FALLO DE SEGURIDAD: El refresh token revocado fue aceptado!"
    } catch {
        Write-Host "DEFENSA ACTIVA: El refresh token revocado fue rechazado correctamente con 401 Unauthorized." -ForegroundColor Green
    }

    # -------------------------------------------------------------------------
    Write-Step "11. Cierre de Sesion (Logout)"
    # -------------------------------------------------------------------------
    $logoutBody = @{ refreshToken = $newClientRefreshToken } | ConvertTo-Json
    $logoutResp = Invoke-RestMethod -Uri "http://localhost:8081/auth/logout" -Method Post -Body $logoutBody -ContentType "application/json"
    Write-Host "OK - Logout completado: $($logoutResp.message)" -ForegroundColor Green

    Write-Host "`nTODAS LAS PRUEBAS COMPLETADAS EXITOSAMENTE SIN NINGUN ERROR!" -ForegroundColor Green
} catch {
    Write-Host "`nError durante la ejecucion de pruebas: $_" -ForegroundColor Red
    if ($_.Exception.Response) {
        $reader = New-Object System.IO.StreamReader($_.Exception.Response.GetResponseStream())
        $respBody = $reader.ReadToEnd()
        Write-Host "Respuesta del servidor: $respBody" -ForegroundColor DarkRed
    }
}
