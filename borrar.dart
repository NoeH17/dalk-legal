// ...existing code...

class _VerificationCallbackWidgetState extends State<VerificationCallbackWidget> {
  late VerificationCallbackModel _model;
  bool _isChecking = true;
  String _statusMessage = 'Verificando tu identidad...';
  RealtimeChannel? _channel;
  Timer? _pollingTimer;
  bool _hasProcessedResult = false;
  int _pollingAttempts = 0;
  static const int _maxPollingAttempts = 120; // 120 * 3s = 6 minutos max (ajustado para VerificaMex)

  @override
  void initState() {
    super.initState();
    _model = createModel(context, () => VerificationCallbackModel());

    debugPrint('🚀 ========================================');
    debugPrint('🚀 VerificationCallbackPage iniciado');
    debugPrint('🚀 ========================================');
    debugPrint('User ID recibido: ${widget.userId}');
    debugPrint('Session ID recibido: ${widget.sessionId}');

    _checkVerificationStatus();
    _listenVerificationStatus();
    _startPolling();
  }

  // ...existing code...

  void _startPolling() {
    debugPrint('⏰ Iniciando polling cada 3 segundos (max 6 minutos)');
    
    _pollingTimer = Timer.periodic(const Duration(seconds: 3), (timer) {
      _pollingAttempts++;
      
      if (_hasProcessedResult) {
        debugPrint('⏰ Polling detenido (resultado procesado)');
        timer.cancel();
        return;
      }

      if (_pollingAttempts >= _maxPollingAttempts) {
        debugPrint('⏰ Polling detenido (timeout - 6 minutos)');
        timer.cancel();
        _handleTimeout();
        return;
      }
      
      debugPrint('⏰ Polling #$_pollingAttempts de $_maxPollingAttempts');
      _checkVerificationStatus();
    });
  }

  // ...existing code...

  // 🔑 PROCESAR STATUS (MODIFICADO PARA MANEJAR TODOS LOS ESTADOS)
  void _processVerificationStatus(Map<String, dynamic> data) {
    if (_hasProcessedResult) {
      debugPrint('⚠️ Resultado ya procesado, ignorando...');
      return;
    }

    final status = data['status'] as String?;
    final result = data['verification_result'] as int?;
    final failureReason = data['failure_reason'] as String?;
    final ineStatus = data['ine_status'] as bool? ?? false;
    final curpStatus = data['curp_status'] as bool? ?? false;

    debugPrint('📊 ========================================');
    debugPrint('📊 PROCESANDO STATUS');
    debugPrint('📊 ========================================');
    debugPrint('Status: $status');
    debugPrint('Result: $result');
    debugPrint('INE Status: $ineStatus');
    debugPrint('CURP Status: $curpStatus');
    debugPrint('Updated at: ${data['updated_at']}');
    debugPrint('Failure Reason: $failureReason');

    if (!mounted) return;

    // ✅ ESTADOS FINALES
    switch (status) {
      case 'completed':
        debugPrint('✅ ========================================');
        debugPrint('✅ VERIFICACIÓN EXITOSA!');
        debugPrint('✅ ========================================');
        
        _hasProcessedResult = true;
        _pollingTimer?.cancel();
        
        setState(() {
          _statusMessage = '¡Verificación exitosa! 🎉';
          _isChecking = false;
        });

        // ⚠️ VERIFICAR SI HAY WARNING DE INE/CURP
        if (failureReason != null && failureReason.contains('pero falló INE/CURP')) {
          debugPrint('⚠️ WARNING: Verificación exitosa pero con observaciones en INE/CURP');
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Verificación completada con observaciones'),
              backgroundColor: Colors.orange,
              duration: const Duration(seconds: 2),
            ),
          );
        }

        Future.delayed(const Duration(seconds: 2), () {
          if (mounted) {
            debugPrint('🏠 Navegando a /walker/home');
            context.go('/walker/home');
          }
        });
        break;

      case 'failed':
      case 'FAILED':
        debugPrint('❌ VERIFICACIÓN FALLIDA');
        _hasProcessedResult = true;
        _pollingTimer?.cancel();
        _handleAutomaticFailure(failureReason ?? 'Verificación fallida');
        break;

      case 'cancelled':
      case 'CANCELLED':
        debugPrint('🚫 VERIFICACIÓN CANCELADA POR EL USUARIO');
        _hasProcessedResult = true;
        _pollingTimer?.cancel();
        _handleAutomaticFailure('Cancelaste el proceso de verificación');
        break;

      // ⏳ ESTADOS INTERMEDIOS (ESPERAR)
      case 'OPEN':
        debugPrint('🟡 Estado: OPEN - Esperando que el usuario complete el proceso');
        setState(() {
          _statusMessage = 'Esperando que completes la verificación...';
        });
        break;

      case 'VERIFYING':
        debugPrint('🔄 Estado: VERIFYING - VerificaMex está procesando los datos');
        setState(() {
          _statusMessage = 'Procesando tu verificación...\n(Esto puede tardar 3-5 minutos)';
        });
        break;

      case 'FINISHED':
        debugPrint('✅ Estado: FINISHED - Procesando resultado final');
        // Este caso se manejará cuando el webhook actualice a 'completed' o 'failed'
        setState(() {
          _statusMessage = 'Finalizando verificación...';
        });
        break;

      case 'pending':
        debugPrint('⏳ Estado: pending - Iniciando verificación');
        setState(() {
          _statusMessage = 'Iniciando verificación...';
        });
        break;

      default:
        debugPrint('⚠️ Estado desconocido: $status');
        setState(() {
          _statusMessage = 'Verificando... ($status)';
        });
    }
  }

  // ⏱️ TIMEOUT (MODIFICADO)
  void _handleTimeout() {
    if (_hasProcessedResult) return;
    
    debugPrint('⏱️ ========================================');
    debugPrint('⏱️ TIMEOUT: Verificación excedió el tiempo máximo (6 minutos)');
    debugPrint('⏱️ ========================================');
    
    setState(() {
      _isChecking = false;
      _statusMessage = 'La verificación está tardando más de lo esperado';
    });

    if (mounted) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          backgroundColor: const Color(0xFF1A2332),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.0)),
          title: Text(
            'Verificación en proceso',
            style: FlutterFlowTheme.of(context).headlineSmall.override(
                  font: GoogleFonts.lexend(),
                  color: Colors.white,
                  fontSize: 18,
                ),
          ),
          content: Text(
            'Tu verificación está tardando más de lo esperado. Esto es normal y puede tardar hasta 5 minutos.\n\n¿Qué deseas hacer?',
            style: FlutterFlowTheme.of(context).bodyMedium.override(
                  font: GoogleFonts.lexend(),
                  color: Colors.white70,
                ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                // Reiniciar polling
                _pollingAttempts = 0;
                _startPolling();
              },
              child: const Text('Seguir esperando', style: TextStyle(color: Colors.white70)),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                context.go('/');
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: FlutterFlowTheme.of(context).primary,
              ),
              child: const Text('Volver al inicio', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      );
    }
  }

  // ...existing code...

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: FlutterFlowTheme.of(context).secondary,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (_isChecking)
                CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(
                    FlutterFlowTheme.of(context).primary,
                  ),
                ),
              const SizedBox(height: 24),
              Text(
                _statusMessage,
                style: FlutterFlowTheme.of(context).bodyLarge.override(
                  font: GoogleFonts.lexend(),
                  color: Colors.white,
                  fontSize: 18,
                ),
                textAlign: TextAlign.center,
              ),
              if (!_isChecking && _statusMessage.contains('exitosa'))
                const SizedBox(height: 16),
              if (!_isChecking && _statusMessage.contains('exitosa'))
                const Icon(Icons.check_circle, color: Colors.green, size: 64),
              
              // 🔧 INFO DE DEBUG
              const SizedBox(height: 40),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.black26,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Debug Info:',
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'User ID: ${widget.userId.isEmpty ? "NULL ❌" : widget.userId}',
                      style: TextStyle(
                        color: widget.userId.isEmpty ? Colors.red : Colors.white70,
                        fontSize: 11,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Session: ${widget.sessionId}',
                      style: const TextStyle(color: Colors.white70, fontSize: 11),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Polling: ${_pollingTimer?.isActive ?? false ? "Activo ($_pollingAttempts/$_maxPollingAttempts) ✅" : "Inactivo"}',
                      style: const TextStyle(color: Colors.white70, fontSize: 11),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Realtime: ${_channel != null ? "Conectado ✅" : "Desconectado"}',
                      style: const TextStyle(color: Colors.white70, fontSize: 11),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}