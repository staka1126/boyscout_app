      child: Scaffold(
        appBar: AppBar(
          title: Text(isNew ? 'スカウト追加' : 'スカウト編集'),
          leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: _onBack),
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: _saving ? null : _save,
          icon: _saving
              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : const Icon(Icons.save_outlined),
          label: const Text('保存'),
        ),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),