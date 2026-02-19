import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_colors.dart';
import '../../widgets/empty_state.dart';
import '../../providers/chat_providers.dart';
import '../../providers/agent_providers.dart';
import '../../models/agent.dart';
import '../../models/agent_config.dart';
import '../../models/chat_message.dart';

class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  final _searchController = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Access all chat states
    final chatMap = ref.watch(chatProvider);
    final agents = ref.watch(agentsProvider);
    
    // Filter results
    final results = <_SearchResult>[];
    if (_query.isNotEmpty) {
      for (final entry in chatMap.entries) {
        final agentId = entry.key;
        final chatState = entry.value;
        final agent = agents.firstWhere(
          (a) => a.id == agentId, 
          orElse: () => Agent(
            id: agentId, 
            config: const AgentConfig(
               id: 'mock',
               name: 'Unknown Agent', 
               icon: Icons.help_outline,
               baseUrl: '',
               apiKey: '',
               type: AgentType.openaiCompatible,
            ),
            version: '1.0.0',
            latencyMs: 0,
            status: AgentStatus.offline, 
            activity: 'Unknown',
          )
        );

        for (final msg in chatState.messages) {
          if (msg.content.toLowerCase().contains(_query.toLowerCase())) {
            results.add(_SearchResult(agent: agent, message: msg));
          }
        }
      }
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            // Header & Search Bar
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Search',
                    style: GoogleFonts.inter(
                      fontSize: 24,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _searchController,
                    onChanged: (val) => setState(() => _query = val),
                    style: GoogleFonts.inter(color: AppColors.textPrimary),
                    decoration: InputDecoration(
                      hintText: 'Search across all conversations...',
                      hintStyle: GoogleFonts.inter(color: AppColors.textSecondary),
                      prefixIcon: const Icon(Icons.search, color: AppColors.textSecondary),
                      filled: true,
                      fillColor: AppColors.surface,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: AppColors.border),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: AppColors.border),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: AppColors.accentPurple),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Results List
            Expanded(
              child: _query.isEmpty
                  ? const EmptyState(
                      icon: Icons.search,
                      title: 'Search Conversations',
                      description: 'Type above to search across all your agent interactions.',
                    )
                  : results.isEmpty
                      ? const EmptyState(
                          icon: Icons.search_off,
                          title: 'No matches found',
                          description: 'Try adjusting your search query.',
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: results.length,
                          itemBuilder: (context, index) {
                            final result = results[index];
                            return _SearchResultTile(result: result);
                          },
                        ),
            ),
            const SizedBox(height: 80), // Floating dock space
          ],
        ),
      ),
    );
  }
}

class _SearchResult {
  final Agent agent;
  final ChatMessage message;

  _SearchResult({required this.agent, required this.message});
}

class _SearchResultTile extends ConsumerWidget {
  final _SearchResult result;

  const _SearchResultTile({required this.result});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return GestureDetector(
      onTap: () {
        context.push('/agents/${result.agent.id}/chat');
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppColors.cardBorder),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  result.message.role == MessageRole.user 
                      ? Icons.person_outline 
                      : Icons.smart_toy_outlined,
                  size: 14,
                  color: AppColors.textSecondary,
                ),
                const SizedBox(width: 8),
                Text(
                  result.agent.name,
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const Spacer(),
                Text(
                  _formatDate(result.message.timestamp),
                  style: GoogleFonts.jetBrainsMono(
                    fontSize: 10,
                    color: AppColors.textSecondary.withValues(alpha: 0.5),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              result.message.content,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.jetBrainsMono(
                fontSize: 12,
                color: AppColors.textPrimary,
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime dt) {
    return '${dt.hour}:${dt.minute.toString().padLeft(2, '0')} ${dt.day}/${dt.month}';
  }
}
