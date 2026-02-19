import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';
import '../../core/theme/app_colors.dart';
import '../../models/agent.dart';
import '../../models/agent_config.dart';
import '../../providers/agent_providers.dart';
import '../../services/health_service.dart';

class AddAgentScreen extends ConsumerStatefulWidget {
  const AddAgentScreen({super.key});

  @override
  ConsumerState<AddAgentScreen> createState() => _AddAgentScreenState();
}

class _AddAgentScreenState extends ConsumerState<AddAgentScreen> {
  final _formKey = GlobalKey<FormState>();
  
  // Controllers
  final _nameController = TextEditingController();
  final _urlController = TextEditingController();
  final _apiKeyController = TextEditingController();
  final _modelController = TextEditingController();
  final _systemPromptController = TextEditingController();
  final _sessionKeyController = TextEditingController();

  AgentType _selectedType = AgentType.openaiCompatible;
  String _selectedThinkingLevel = 'low';

  bool get _isOpenClaw => _selectedType == AgentType.openClaw;
  
  // Test State
  bool _isTesting = false;
  String? _testResult;
  bool _testSuccess = false;

  @override
  void dispose() {
    _nameController.dispose();
    _urlController.dispose();
    _apiKeyController.dispose();
    _modelController.dispose();
    _systemPromptController.dispose();
    _sessionKeyController.dispose();
    super.dispose();
  }

  Future<void> _testConnection() async {
    if (_urlController.text.isEmpty) {
      setState(() {
        _testResult = 'URL required';
        _testSuccess = false;
      });
      return;
    }

    setState(() {
      _isTesting = true;
      _testResult = null;
    });

    try {
      final healthService = ref.read(healthServiceProvider);
      final result = await healthService.checkHealth(
        _urlController.text.trim(),
        _selectedType,
        apiKey: _apiKeyController.text.trim(),
      );
      
      if (mounted) {
        setState(() {
          _isTesting = false;
          _testSuccess = result.isHealthy;
          _testResult = result.message;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isTesting = false;
          _testSuccess = false;
          _testResult = 'Connection failed: $e';
        });
      }
    }
  }

  void _saveAgent() {
    if (!_formKey.currentState!.validate()) return;

    final config = AgentConfig(
      id: const Uuid().v4(),
      name: _nameController.text.trim(),
      icon: Icons.smart_toy, // Default
      baseUrl: _urlController.text.trim(),
      apiKey: _apiKeyController.text.trim(),
      type: _selectedType,
      modelName: _modelController.text.isNotEmpty ? _modelController.text.trim() : null,
      systemPrompt: _systemPromptController.text.isNotEmpty ? _systemPromptController.text.trim() : '',
      deviceId: _selectedType == AgentType.openClaw ? const Uuid().v4() : '',
      thinkingLevel: _isOpenClaw ? _selectedThinkingLevel : null,
      sessionKey: (_isOpenClaw && _sessionKeyController.text.isNotEmpty)
          ? _sessionKeyController.text.trim()
          : null,
    );

    final newAgent = Agent(
      id: config.id,
      config: config,
      version: '1.0.0',
      latencyMs: 0,
      status: AgentStatus.offline, // Default to offline until connected
      activity: 'Idle',
    );

    ref.read(agentsProvider.notifier).addAgent(newAgent);
    context.pop();
  }

  void _autoFillDefaults(AgentType type) {
    setState(() {
      _selectedType = type;
      switch (type) {
        case AgentType.ollama:
          if (_urlController.text.isEmpty) _urlController.text = 'http://localhost:11434/api/chat';
          if (_modelController.text.isEmpty) _modelController.text = 'llama3';
          break;
        case AgentType.openaiCompatible:
          if (_urlController.text.isEmpty) _urlController.text = 'https://api.openai.com/v1/chat/completions';
          if (_modelController.text.isEmpty) _modelController.text = 'gpt-4o';
          break;
        case AgentType.anthropicCompatible:
          if (_urlController.text.isEmpty) _urlController.text = 'https://api.anthropic.com/v1/messages';
          if (_modelController.text.isEmpty) _modelController.text = 'claude-3-5-sonnet-20240620';
          break;
        case AgentType.openClaw:
          if (_urlController.text.isEmpty) _urlController.text = 'wss://nomi.unschackle.com';
          break;
        case AgentType.custom:
          break;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text('Add New Agent', style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w600)),
        backgroundColor: AppColors.background,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: AppColors.textSecondary),
          onPressed: () => context.pop(),
        ),
        actions: [
          TextButton(
            onPressed: _saveAgent,
            child: Text(
              'Save',
              style: GoogleFonts.inter(
                color: AppColors.accentPurple,
                fontWeight: FontWeight.w600,
              ),
            ),
          )
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Type Selection
              Text('Agent Type', style: _labelStyle),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: _fieldDecoration,
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<AgentType>(
                    value: _selectedType,
                    isExpanded: true,
                    dropdownColor: AppColors.surface,
                    style: GoogleFonts.inter(color: AppColors.textPrimary),
                    items: AgentType.values.map((type) {
                      return DropdownMenuItem(
                        value: type,
                        child: Text(type.name.toUpperCase()),
                      );
                    }).toList(),
                    onChanged: (val) {
                      if (val != null) _autoFillDefaults(val);
                    },
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Name
              Text('Name', style: _labelStyle),
              const SizedBox(height: 8),
              TextFormField(
                controller: _nameController,
                style: _inputStyle,
                decoration: _inputDecoration('e.g. My Local Assistant'),
                validator: (val) => val == null || val.isEmpty ? 'Required' : null,
              ),
              const SizedBox(height: 24),

              // Base URL
              Text('Endpoint URL', style: _labelStyle),
              const SizedBox(height: 8),
              TextFormField(
                controller: _urlController,
                style: _inputStyle,
                decoration: _inputDecoration('https://...'),
                validator: (val) => val == null || val.isEmpty ? 'Required' : null,
              ),
              const SizedBox(height: 24),

              // API Key / Gateway Token
              Text(
                _isOpenClaw ? 'Gateway Token (Optional)' : 'API Key (Optional)',
                style: _labelStyle,
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _apiKeyController,
                style: _inputStyle,
                obscureText: true,
                decoration: _inputDecoration(_isOpenClaw ? 'gw-...' : 'sk-...'),
              ),
              const SizedBox(height: 24),

              // Model Name (hidden for OpenClaw)
              if (!_isOpenClaw) ...[
                Text('Model Name', style: _labelStyle),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _modelController,
                  style: _inputStyle,
                  decoration: _inputDecoration('e.g. gpt-4o'),
                ),
                const SizedBox(height: 24),
              ],

              // System Prompt (hidden for OpenClaw)
              if (!_isOpenClaw) ...[
                Text('System Instruction', style: _labelStyle),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _systemPromptController,
                  style: _inputStyle,
                  maxLines: 3,
                  decoration: _inputDecoration('You are a helpful assistant...'),
                ),
                const SizedBox(height: 24),
              ],

              // OpenClaw-only: Thinking Level
              if (_isOpenClaw) ...[
                Text('Thinking Level', style: _labelStyle),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: _fieldDecoration,
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: _selectedThinkingLevel,
                      isExpanded: true,
                      dropdownColor: AppColors.surface,
                      style: GoogleFonts.inter(color: AppColors.textPrimary),
                      items: const [
                        DropdownMenuItem(value: 'off', child: Text('Off')),
                        DropdownMenuItem(value: 'low', child: Text('Low')),
                        DropdownMenuItem(value: 'high', child: Text('High')),
                      ],
                      onChanged: (val) {
                        if (val != null) setState(() => _selectedThinkingLevel = val);
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 24),
              ],

              // OpenClaw-only: Session Key
              if (_isOpenClaw) ...[
                Text('Session Key', style: _labelStyle),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _sessionKeyController,
                  style: _inputStyle,
                  decoration: _inputDecoration('main'),
                ),
                const SizedBox(height: 24),
              ],

              const SizedBox(height: 8),

              // Test Connection
              OutlinedButton(
                onPressed: _isTesting ? null : _testConnection,
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.textPrimary,
                  side: const BorderSide(color: AppColors.border),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  minimumSize: const Size(double.infinity, 50),
                ),
                child: _isTesting
                   ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                   : Text('Test Connection', style: GoogleFonts.inter(fontWeight: FontWeight.w500)),
              ),
              
              if (_testResult != null) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: _testSuccess ? AppColors.success.withValues(alpha: 0.1) : AppColors.error.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: _testSuccess ? AppColors.success.withValues(alpha: 0.3) : AppColors.error.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        _testSuccess ? Icons.check_circle : Icons.error,
                        color: _testSuccess ? AppColors.success : AppColors.error,
                        size: 20,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          _testResult!,
                          style: GoogleFonts.jetBrainsMono(
                            fontSize: 12,
                            color: _testSuccess ? AppColors.success : AppColors.error,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  TextStyle get _labelStyle => GoogleFonts.inter(
    fontSize: 13,
    fontWeight: FontWeight.w500,
    color: AppColors.textSecondary,
  );

  TextStyle get _inputStyle => GoogleFonts.inter(
    color: AppColors.textPrimary,
    fontSize: 14,
  );

  BoxDecoration get _fieldDecoration => BoxDecoration(
    color: AppColors.surface,
    borderRadius: BorderRadius.circular(8),
    border: Border.all(color: AppColors.border),
  );

  InputDecoration _inputDecoration(String hint) {
    return InputDecoration(
      hintText: hint,
      hintStyle: GoogleFonts.inter(color: AppColors.textSecondary.withValues(alpha: 0.5)),
      filled: true,
      fillColor: AppColors.surface,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: AppColors.border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: AppColors.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: AppColors.accentPurple),
      ),
    );
  }
}
