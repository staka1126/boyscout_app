  void _onTapDown1(TapDownDetails _) {
    _timer1?.cancel();
    if (mounted) setState(() => _pressing1 = true);
    _timer1 = Timer(const Duration(seconds: 10), () {
      if (!mounted) return;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() { _pressing1 = false; _showConfirm = true; });
      });
    });
  }

  void _onTapUp1(TapUpDetails _) {
    _timer1?.cancel();
    if (mounted) setState(() => _pressing1 = false);
  }

  void _onTapDown2(TapDownDetails _) {
    _timer2?.cancel();
    if (mounted) setState(() => _pressing2 = true);
    _timer2 = Timer(const Duration(seconds: 10), () {
      if (mounted) _executeDeleteAll();
    });
  }

  void _onTapUp2(TapUpDetails _) {
    _timer2?.cancel();
    if (mounted) setState(() => _pressing2 = false);
  }