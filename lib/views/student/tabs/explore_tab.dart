import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../core/formatters.dart';
import '../../../models/models.dart';
import '../../../navigation/app_router.dart';
import '../../../repositories/event_repository.dart';
import '../../../services/app_services.dart';
import '../../../theme/app_colors.dart';
import '../../../viewmodels/auth_viewmodel.dart';
import '../../../viewmodels/student/student_viewmodels.dart';
import '../../../widgets/common_widgets.dart';
import '../../../widgets/event_card.dart';
import '../register_flow.dart';

/// Explore: search + filter by category, date, venue, price, organiser.
/// Also lets students follow organisers and see saved events.
class StudentExploreTab extends StatefulWidget {
  const StudentExploreTab({super.key});

  @override
  State<StudentExploreTab> createState() => _StudentExploreTabState();
}

class _StudentExploreTabState extends State<StudentExploreTab> {
  late final TextEditingController _search;
  bool _savedOnly = false;

  @override
  void initState() {
    super.initState();
    _search = TextEditingController(text: context.read<EventFeedViewModel>().filter.query);
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _openFilters() async {
    final feed = context.read<EventFeedViewModel>();
    final result = await showModalBottomSheet<EventFilter>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _FilterSheet(initial: feed.filter, venues: feed.venues),
    );
    if (result != null) feed.setFilter(result);
  }

  @override
  Widget build(BuildContext context) {
    final feed = context.watch<EventFeedViewModel>();
    final user = context.watch<AuthViewModel>().user!;
    var events = feed.filtered;
    if (_savedOnly) {
      events = events.where((e) => user.savedEventIds.contains(e.id)).toList();
    }
    final f = feed.filter;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Explore'),
        actions: [
          IconButton(
            tooltip: 'Saved events',
            onPressed: () => setState(() => _savedOnly = !_savedOnly),
            icon: Icon(_savedOnly ? Icons.bookmark : Icons.bookmark_border),
          ),
          IconButton(
            tooltip: 'Clubs & organisers',
            onPressed: () => _showOrganisers(context),
            icon: const Icon(Icons.groups_outlined),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _search,
                    onChanged: feed.setQuery,
                    textInputAction: TextInputAction.search,
                    decoration: InputDecoration(
                      hintText: 'Search events, venues, clubs…',
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: _search.text.isEmpty
                          ? null
                          : IconButton(
                              icon: const Icon(Icons.clear),
                              onPressed: () {
                                _search.clear();
                                feed.setQuery('');
                              },
                            ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Badge(
                  isLabelVisible: f.hasActiveFilters,
                  backgroundColor: AppColors.orange,
                  child: IconButton.filled(
                    tooltip: 'Filters',
                    onPressed: _openFilters,
                    icon: const Icon(Icons.tune),
                    style: IconButton.styleFrom(
                      backgroundColor: AppColors.indigo,
                      minimumSize: const Size(52, 52),
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (f.hasActiveFilters || _savedOnly)
            SizedBox(
              height: 46,
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                scrollDirection: Axis.horizontal,
                children: [
                  if (_savedOnly)
                    _ActiveChip('Saved', () => setState(() => _savedOnly = false)),
                  if (f.category != null)
                    _ActiveChip(f.category!, () => feed.setFilter(f.copyWith(clearCategory: true))),
                  if (f.date != null)
                    _ActiveChip(Fmt.shortDate(f.date!), () => feed.setFilter(f.copyWith(clearDate: true))),
                  if (f.venue != null)
                    _ActiveChip(f.venue!, () => feed.setFilter(f.copyWith(clearVenue: true))),
                  if (f.freeOnly != null)
                    _ActiveChip(f.freeOnly! ? 'Free' : 'Paid', () => feed.setFilter(f.copyWith(clearFree: true))),
                  if (f.organiserId != null)
                    _ActiveChip('Organiser', () => feed.setFilter(f.copyWith(clearOrganiser: true))),
                  TextButton(onPressed: feed.clearFilters, child: const Text('Clear all')),
                ],
              ),
            ),
          Expanded(
            child: feed.loading
                ? const LoadingView()
                : events.isEmpty
                    ? EmptyState(
                        icon: _savedOnly ? Icons.bookmark_border : Icons.search_off,
                        title: _savedOnly ? 'No saved events' : 'No events match',
                        message: _savedOnly
                            ? 'Tap the bookmark on any event to save it for later.'
                            : 'Try a different search or clear some filters.',
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                        itemCount: events.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 14),
                        itemBuilder: (context, i) {
                          final e = events[i];
                          final saved = user.savedEventIds.contains(e.id);
                          return EventCard(
                            event: e,
                            registration: feed.registrationFor(e.id),
                            saved: saved,
                            onToggleSave: () => feed.toggleSave(e.id, currentlySaved: saved),
                            onTap: () => context.push(Routes.eventDetails(e.id)),
                            onRegister: () => registerForEvent(context, e),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }

  void _showOrganisers(BuildContext context) {
    final services = context.read<AppServices>();
    final feed = context.read<EventFeedViewModel>();
    final uid = context.read<AuthViewModel>().user!.uid;
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (ctx) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.6,
        builder: (ctx, controller) => StreamBuilder<AppUser?>(
          stream: services.users.watch(uid),
          builder: (ctx, meSnap) => StreamBuilder<List<AppUser>>(
            stream: services.users.watchOrganisers(),
            builder: (ctx, snap) {
              if (!snap.hasData) return const LoadingView();
              final organisers = snap.data!;
              final following = meSnap.data?.followingOrganiserIds ?? const [];
              if (organisers.isEmpty) {
                return const EmptyState(icon: Icons.groups_outlined, title: 'No organisers yet');
              }
              return ListView.builder(
                controller: controller,
                padding: const EdgeInsets.all(16),
                itemCount: organisers.length + 1,
                itemBuilder: (ctx, i) {
                  if (i == 0) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Text(
                        'Clubs & organisers',
                        style: Theme.of(ctx).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
                      ),
                    );
                  }
                  final o = organisers[i - 1];
                  final isFollowing = following.contains(o.uid);
                  return ListTile(
                    leading: UserAvatar(name: o.organisationName ?? o.fullName, photoUrl: o.photoUrl),
                    title: Text(o.organisationName ?? o.fullName),
                    subtitle: Text(o.fullName),
                    onTap: () {
                      feed.setFilter(feed.filter.copyWith(organiserId: o.uid));
                      Navigator.pop(ctx);
                    },
                    trailing: FilledButton.tonal(
                      onPressed: () => feed.toggleFollow(o.uid, currentlyFollowing: isFollowing),
                      child: Text(isFollowing ? 'Following' : 'Follow'),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ),
    );
  }
}

class _ActiveChip extends StatelessWidget {
  const _ActiveChip(this.label, this.onRemove);
  final String label;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: InputChip(
        label: Text(label),
        selected: true,
        onDeleted: onRemove,
        deleteIconColor: AppColors.white,
        labelStyle: const TextStyle(color: AppColors.white),
        selectedColor: AppColors.indigo,
      ),
    );
  }
}

class _FilterSheet extends StatefulWidget {
  const _FilterSheet({required this.initial, required this.venues});
  final EventFilter initial;
  final List<String> venues;

  @override
  State<_FilterSheet> createState() => _FilterSheetState();
}

class _FilterSheetState extends State<_FilterSheet> {
  late EventFilter _f = widget.initial;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Filter events', style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 16),
            Text('Category', style: theme.textTheme.labelLarge),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: kEventCategories.map((c) {
                final sel = _f.category == c;
                return ChoiceChip(
                  label: Text(c),
                  selected: sel,
                  labelStyle: TextStyle(color: sel ? AppColors.white : AppColors.midnight),
                  onSelected: (_) => setState(
                    () => _f = sel ? _f.copyWith(clearCategory: true) : _f.copyWith(category: c),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 16),
            Text('Price', style: theme.textTheme.labelLarge),
            const SizedBox(height: 8),
            SegmentedButton<int>(
              segments: const [
                ButtonSegment(value: 0, label: Text('Any')),
                ButtonSegment(value: 1, label: Text('Free')),
                ButtonSegment(value: 2, label: Text('Paid')),
              ],
              selected: {_f.freeOnly == null ? 0 : (_f.freeOnly! ? 1 : 2)},
              onSelectionChanged: (s) => setState(() {
                final v = s.first;
                _f = v == 0 ? _f.copyWith(clearFree: true) : _f.copyWith(freeOnly: v == 1);
              }),
            ),
            const SizedBox(height: 16),
            Text('Date', style: theme.textTheme.labelLarge),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: _f.date ?? DateTime.now(),
                  firstDate: DateTime.now().subtract(const Duration(days: 1)),
                  lastDate: DateTime.now().add(const Duration(days: 365)),
                );
                if (picked != null) setState(() => _f = _f.copyWith(date: picked));
              },
              icon: const Icon(Icons.calendar_today_outlined),
              label: Text(_f.date == null ? 'Any date' : Fmt.date(_f.date!)),
            ),
            if (_f.date != null)
              TextButton(
                onPressed: () => setState(() => _f = _f.copyWith(clearDate: true)),
                child: const Text('Clear date'),
              ),
            const SizedBox(height: 16),
            Text('Venue', style: theme.textTheme.labelLarge),
            const SizedBox(height: 8),
            DropdownButtonFormField<String?>(
              initialValue: widget.venues.contains(_f.venue) ? _f.venue : null,
              isExpanded: true,
              hint: const Text('Any venue'),
              items: [
                const DropdownMenuItem<String?>(value: null, child: Text('Any venue')),
                ...widget.venues.map((v) => DropdownMenuItem<String?>(value: v, child: Text(v, overflow: TextOverflow.ellipsis))),
              ],
              onChanged: (v) => setState(
                () => _f = v == null ? _f.copyWith(clearVenue: true) : _f.copyWith(venue: v),
              ),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context, EventFilter(query: _f.query)),
                    child: const Text('Reset'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(context, _f),
                    child: const Text('Apply'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
