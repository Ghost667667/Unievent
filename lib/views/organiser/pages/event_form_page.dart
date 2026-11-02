import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../core/formatters.dart';
import '../../../core/validators.dart';
import '../../../models/models.dart';
import '../../../navigation/app_router.dart';
import '../../../services/app_services.dart';
import '../../../services/integration_services.dart';
import '../../../services/storage_service.dart';
import '../../../theme/app_colors.dart';
import '../../../viewmodels/auth_viewmodel.dart';
import '../../../widgets/common_widgets.dart';
import '../../../widgets/event_card.dart';

/// Create (from an approved proposal) or edit an event.
class EventFormPage extends StatefulWidget {
  const EventFormPage({super.key, this.proposalId, this.eventId});
  final String? proposalId;
  final String? eventId;

  @override
  State<EventFormPage> createState() => _EventFormPageState();
}

class _EventFormPageState extends State<EventFormPage> {
  final _formKey = GlobalKey<FormState>();
  final _title = TextEditingController();
  final _description = TextEditingController();
  final _venue = TextEditingController();
  final _capacity = TextEditingController(text: '100');
  final _price = TextEditingController(text: '0');
  final _requirements = TextEditingController();
  final _vendorFee = TextEditingController(text: '0');
  final _vendorRequirements = TextEditingController();
  final _vendorFacilities = TextEditingController();
  final _lat = TextEditingController();
  final _lng = TextEditingController();

  String _category = kEventCategories.first;
  String _format = 'Talk';
  DateTime _start = DateTime.now().add(const Duration(days: 14, hours: 2));
  DateTime _end = DateTime.now().add(const Duration(days: 14, hours: 4));
  DateTime? _deadline;
  bool _acceptsVendors = false;
  bool _studentVendorsOnly = true;
  bool _certificate = false;
  bool _photos = true;
  bool _outdoor = false;
  bool _allowWalkIns = false;
  final Set<String> _allowedCategories = {};
  final List<EventSpeaker> _speakers = [];
  final List<ScheduleItem> _schedule = [];
  String? _posterUrl;
  PickedImage? _posterFile;

  Proposal? _proposal;
  Event? _existing;
  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final services = context.read<AppServices>();
    if (widget.eventId != null) {
      final e = await services.events.get(widget.eventId!);
      if (e != null) _applyEvent(e);
    } else if (widget.proposalId != null) {
      final user = context.read<AuthViewModel>().user!;
      final list = await services.proposals.watchByOrganiser(user.uid).first;
      final match = list.where((p) => p.id == widget.proposalId);
      if (match.isNotEmpty) {
        _proposal = match.first;
        _title.text = _proposal!.eventTitle;
        _description.text = _proposal!.description;
        _venue.text = _proposal!.venue;
        _capacity.text = '${_proposal!.expectedAttendance}';
        _category = _proposal!.category;
        _start = _proposal!.proposedDate;
        _end = _start.add(const Duration(hours: 3));
        _acceptsVendors = _proposal!.needsVendors;
      }
    }
    if (mounted) setState(() => _loading = false);
  }

  void _applyEvent(Event e) {
    _existing = e;
    _title.text = e.title;
    _description.text = e.description;
    _venue.text = e.venue;
    _capacity.text = '${e.capacity}';
    _price.text = e.price.toStringAsFixed(e.price == e.price.roundToDouble() ? 0 : 2);
    _requirements.text = e.requirements;
    _vendorFee.text = e.vendorFee.toStringAsFixed(0);
    _vendorRequirements.text = e.vendorRequirements;
    _vendorFacilities.text = e.vendorFacilities.join(', ');
    _lat.text = e.latitude?.toString() ?? '';
    _lng.text = e.longitude?.toString() ?? '';
    _category = e.category;
    _format = e.format;
    _start = e.startTime;
    _end = e.endTime;
    _deadline = e.registrationDeadline;
    _acceptsVendors = e.acceptsVendors;
    _studentVendorsOnly = e.studentVendorsOnly;
    _certificate = e.certificateOffered;
    _photos = e.photographyAllowed;
    _outdoor = e.isOutdoor;
    _allowWalkIns = e.allowWalkIns;
    _allowedCategories.addAll(e.allowedProductCategories);
    _speakers.addAll(e.speakers);
    _schedule.addAll(e.schedule);
    _posterUrl = e.posterUrl;
  }

  @override
  void dispose() {
    for (final c in [_title, _description, _venue, _capacity, _price, _requirements, _vendorFee, _vendorRequirements, _vendorFacilities, _lat, _lng]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _pickDateTime({required bool start}) async {
    final initial = start ? _start : _end;
    final d = await showDatePicker(context: context, initialDate: initial, firstDate: DateTime.now().subtract(const Duration(days: 1)), lastDate: DateTime.now().add(const Duration(days: 730)));
    if (d == null || !mounted) return;
    final t = await showTimePicker(context: context, initialTime: TimeOfDay.fromDateTime(initial));
    if (t == null) return;
    final dt = DateTime(d.year, d.month, d.day, t.hour, t.minute);
    setState(() {
      if (start) {
        final duration = _end.difference(_start);
        _start = dt;
        _end = dt.add(duration.isNegative ? const Duration(hours: 2) : duration);
      } else {
        _end = dt;
      }
    });
  }

  Future<void> _pickPoster() async {
    final file = await context.read<AppServices>().storage.pickImage();
    if (file != null) setState(() => _posterFile = file);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_end.isBefore(_start)) {
      showAppSnackBar(context, 'End time must be after the start time.', error: true);
      return;
    }
    setState(() => _saving = true);
    final services = context.read<AppServices>();
    final user = context.read<AuthViewModel>().user!;
    try {
      var posterUrl = _posterUrl;
      final id = _existing?.id ?? '';
      if (_posterFile != null) {
        posterUrl = await services.storage.upload(_posterFile!, 'posters/${id.isEmpty ? user.uid : id}');
      }
      final event = Event(
        id: id,
        title: _title.text.trim(),
        description: _description.text.trim(),
        category: _category,
        organiserId: _existing?.organiserId ?? user.uid,
        organiserName: _existing?.organiserName ?? (user.organisationName ?? user.fullName),
        proposalId: _existing?.proposalId ?? _proposal?.id,
        startTime: _start,
        endTime: _end,
        venue: _venue.text.trim(),
        latitude: double.tryParse(_lat.text.trim()),
        longitude: double.tryParse(_lng.text.trim()),
        posterUrl: posterUrl,
        capacity: int.parse(_capacity.text.trim()),
        registeredCount: _existing?.registeredCount ?? 0,
        confirmedCount: _existing?.confirmedCount ?? 0,
        waitlistCount: _existing?.waitlistCount ?? 0,
        attendedCount: _existing?.attendedCount ?? 0,
        price: double.tryParse(_price.text.trim()) ?? 0,
        status: _existing?.status ?? EventStatus.upcoming,
        registrationDeadline: _deadline,
        allowWalkIns: _allowWalkIns,
        acceptsVendors: _acceptsVendors,
        vendorFee: double.tryParse(_vendorFee.text.trim()) ?? 0,
        vendorFacilities: _vendorFacilities.text.split(',').map((s) => s.trim()).where((s) => s.isNotEmpty).toList(),
        vendorRequirements: _vendorRequirements.text.trim(),
        allowedProductCategories: _allowedCategories.toList(),
        studentVendorsOnly: _studentVendorsOnly,
        speakers: List.of(_speakers),
        schedule: List.of(_schedule),
        requirements: _requirements.text.trim(),
        certificateOffered: _certificate,
        photographyAllowed: _photos,
        format: _format,
        seatRescueHoursBefore: _existing?.seatRescueHoursBefore ?? 24,
        seatRescueDeadlineHours: _existing?.seatRescueDeadlineHours ?? 6,
        seatRescueSentAt: _existing?.seatRescueSentAt,
        seatRescueReleasedAt: _existing?.seatRescueReleasedAt,
        isOutdoor: _outdoor,
        createdAt: _existing?.createdAt,
      );

      String eventId;
      if (_existing == null) {
        eventId = await services.events.create(event);
        if (_proposal != null) await services.proposals.linkEvent(_proposal!.id, eventId);
        // Tell students who follow this organiser.
        final followers = await services.users.fetchFollowers(event.organiserId);
        if (followers.isNotEmpty) {
          await services.notifications.notifyUsers(
            followers,
            title: 'New event from ${event.organiserName}',
            body: '${event.title} • ${Fmt.dateTime(event.startTime)} • ${event.venue}',
            eventId: eventId,
            type: 'announcement',
          );
        }
      } else {
        eventId = _existing!.id;
        await services.events.save(event);
        // Notify registrants when time or venue changed.
        if (_existing!.startTime != _start || _existing!.venue != _venue.text.trim()) {
          final regs = await services.registrations.fetchByEvent(eventId);
          final changed = _existing!.venue != _venue.text.trim() ? 'venue' : 'time';
          await services.announcements.add(
            Announcement(
              id: '',
              eventId: eventId,
              eventTitle: event.title,
              organiserId: user.uid,
              type: changed == 'venue' ? AnnouncementType.venueChange : AnnouncementType.timeChange,
              title: changed == 'venue' ? 'Venue changed' : 'Time changed',
              body: changed == 'venue'
                  ? 'The event now takes place at ${event.venue}.'
                  : 'The event now starts at ${Fmt.dateTime(event.startTime)}.',
            ),
          );
          await services.notifications.notifyUsers(
            regs.where((r) => r.isActive).map((r) => r.studentId),
            title: '${event.title}: ${changed == 'venue' ? 'venue' : 'time'} changed',
            body: changed == 'venue' ? 'New venue: ${event.venue}' : 'New time: ${Fmt.dateTime(event.startTime)}',
            eventId: eventId,
            type: 'announcement',
          );
        }
      }
      if (!mounted) return;
      showAppSnackBar(context, _existing == null ? 'Event published!' : 'Event updated.', success: true);
      if (_existing == null) {
        context.go(Routes.eventManage(eventId));
      } else {
        context.pop();
      }
    } catch (e) {
      if (mounted) showAppSnackBar(context, 'Could not save event: $e', error: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (_loading) return const Scaffold(body: LoadingView());
    if (widget.eventId == null && _proposal == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Create Event')),
        body: const EmptyState(icon: Icons.lock_outline, title: 'Approved proposal required', message: 'Events can only be created from a proposal approved by Student Affairs.'),
      );
    }

    Widget section(String title, {String? subtitle}) => Padding(
          padding: const EdgeInsets.fromLTRB(0, 22, 0, 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
              if (subtitle != null) Text(subtitle, style: theme.textTheme.bodySmall?.copyWith(color: AppColors.textSecondary)),
            ],
          ),
        );

    return Scaffold(
      appBar: AppBar(title: Text(_existing == null ? 'Create Event' : 'Edit Event')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
          children: [
            if (_proposal != null)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: AppColors.green.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)),
                child: Row(
                  children: [
                    const Icon(Icons.verified, color: AppColors.green),
                    const SizedBox(width: 10),
                    Expanded(child: Text('Approved by Student Affairs • ${_proposal!.eventTitle}', style: theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600))),
                  ],
                ),
              ),

            // Poster
            section('Event poster'),
            GestureDetector(
              onTap: _pickPoster,
              child: Stack(
                children: [
                  if (_posterFile != null)
                    ClipRRect(borderRadius: BorderRadius.circular(16), child: Image.memory(_posterFile!.bytes, height: 170, width: double.infinity, fit: BoxFit.cover))
                  else if (_existing != null || _posterUrl != null)
                    EventPoster(
                      event: Event(
                        id: '', title: _title.text, description: '', category: _category, organiserId: '', organiserName: '',
                        startTime: _start, endTime: _end, venue: '', capacity: 0, posterUrl: _posterUrl,
                      ),
                      height: 170,
                      borderRadius: BorderRadius.circular(16),
                    )
                  else
                    Container(
                      height: 170,
                      decoration: BoxDecoration(color: AppColors.surfaceTint, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppColors.indigo.withValues(alpha: 0.3), style: BorderStyle.solid)),
                      child: const Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.add_photo_alternate_outlined, size: 40, color: AppColors.indigo),
                          SizedBox(height: 6),
                          Text('Upload poster', style: TextStyle(color: AppColors.indigo, fontWeight: FontWeight.w600)),
                        ],
                      ),
                    ),
                  Positioned(
                    right: 10,
                    bottom: 10,
                    child: FilledButton.tonalIcon(onPressed: _pickPoster, icon: const Icon(Icons.edit, size: 16), label: const Text('Change')),
                  ),
                ],
              ),
            ),

            section('Basics'),
            TextFormField(controller: _title, validator: (v) => Validators.required(v, 'Title'), decoration: const InputDecoration(labelText: 'Event title')),
            const SizedBox(height: 12),
            TextFormField(controller: _description, maxLines: 5, validator: (v) => Validators.required(v, 'Description'), decoration: const InputDecoration(labelText: 'Description', alignLabelWithHint: true)),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    initialValue: _category,
                    decoration: const InputDecoration(labelText: 'Category'),
                    items: kEventCategories.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                    onChanged: (v) => setState(() => _category = v!),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    initialValue: _format,
                    decoration: const InputDecoration(labelText: 'Format'),
                    items: const ['Talk', 'Hands-on', 'Social', 'Competition', 'Performance'].map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                    onChanged: (v) => setState(() => _format = v!),
                  ),
                ),
              ],
            ),

            section('Date, time & venue'),
            Row(
              children: [
                Expanded(child: _DateTile(label: 'Starts', value: _start, onTap: () => _pickDateTime(start: true))),
                const SizedBox(width: 12),
                Expanded(child: _DateTile(label: 'Ends', value: _end, onTap: () => _pickDateTime(start: false))),
              ],
            ),
            const SizedBox(height: 12),
            TextFormField(controller: _venue, validator: (v) => Validators.required(v, 'Venue'), decoration: const InputDecoration(labelText: 'Venue', prefixIcon: Icon(Icons.place_outlined))),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(child: TextFormField(controller: _lat, keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true), decoration: const InputDecoration(labelText: 'Latitude (optional)'))),
                const SizedBox(width: 12),
                Expanded(child: TextFormField(controller: _lng, keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true), decoration: const InputDecoration(labelText: 'Longitude (optional)'))),
                IconButton(
                  tooltip: 'Use APU campus',
                  onPressed: () => setState(() {
                    _lat.text = MapsService.apuLat.toString();
                    _lng.text = MapsService.apuLng.toString();
                  }),
                  icon: const Icon(Icons.my_location, color: AppColors.indigo),
                ),
              ],
            ),
            SwitchListTile(contentPadding: EdgeInsets.zero, title: const Text('Outdoor event'), subtitle: const Text('Shows the Open-Meteo weather forecast to attendees'), value: _outdoor, onChanged: (v) => setState(() => _outdoor = v)),

            section('Capacity & registration'),
            Row(
              children: [
                Expanded(child: TextFormField(controller: _capacity, keyboardType: TextInputType.number, validator: (v) => Validators.positiveInt(v, 'Capacity'), decoration: const InputDecoration(labelText: 'Capacity (seats)'))),
                const SizedBox(width: 12),
                Expanded(child: TextFormField(controller: _price, keyboardType: const TextInputType.numberWithOptions(decimal: true), validator: (v) => Validators.money(v, 'Price'), decoration: const InputDecoration(labelText: 'Price (RM, 0 = free)'))),
              ],
            ),
            const SizedBox(height: 12),
            InkWell(
              onTap: () async {
                final d = await showDatePicker(context: context, initialDate: _deadline ?? _start.subtract(const Duration(days: 1)), firstDate: DateTime.now().subtract(const Duration(days: 1)), lastDate: _start);
                if (d != null) setState(() => _deadline = DateTime(d.year, d.month, d.day, 23, 59));
              },
              child: InputDecorator(
                decoration: InputDecoration(
                  labelText: 'Registration deadline (optional)',
                  suffixIcon: _deadline == null ? const Icon(Icons.calendar_today_outlined) : IconButton(icon: const Icon(Icons.clear), onPressed: () => setState(() => _deadline = null)),
                ),
                child: Text(_deadline == null ? 'Closes at capacity or when the event starts' : Fmt.dateTime(_deadline!)),
              ),
            ),
            SwitchListTile(contentPadding: EdgeInsets.zero, title: const Text('Allow walk-ins'), subtitle: const Text('Crew can register unregistered students at the door while seats remain'), value: _allowWalkIns, onChanged: (v) => setState(() => _allowWalkIns = v)),
            SwitchListTile(contentPadding: EdgeInsets.zero, title: const Text('Certificate of attendance offered'), value: _certificate, onChanged: (v) => setState(() => _certificate = v)),
            SwitchListTile(contentPadding: EdgeInsets.zero, title: const Text('Photography allowed'), value: _photos, onChanged: (v) => setState(() => _photos = v)),
            TextFormField(controller: _requirements, maxLines: 2, decoration: const InputDecoration(labelText: 'Requirements / what to bring (optional)', alignLabelWithHint: true)),

            section('Speakers', subtitle: 'Shown on the About tab'),
            ..._speakers.asMap().entries.map(
              (e) => ListTile(
                contentPadding: EdgeInsets.zero,
                leading: UserAvatar(name: e.value.name),
                title: Text(e.value.name),
                subtitle: e.value.title.isEmpty ? null : Text(e.value.title),
                trailing: IconButton(icon: const Icon(Icons.delete_outline), onPressed: () => setState(() => _speakers.removeAt(e.key))),
              ),
            ),
            OutlinedButton.icon(
              onPressed: () async {
                final s = await _twoFieldDialog(context, 'Add speaker', 'Name', 'Title / role');
                if (s != null) setState(() => _speakers.add(EventSpeaker(name: s.$1, title: s.$2)));
              },
              icon: const Icon(Icons.person_add_alt),
              label: const Text('Add speaker'),
            ),

            section('Schedule', subtitle: 'Agenda shown on the Schedule tab'),
            ..._schedule.asMap().entries.map(
              (e) => ListTile(
                contentPadding: EdgeInsets.zero,
                leading: SizedBox(width: 72, child: Text(e.value.time, style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.indigo))),
                title: Text(e.value.title),
                trailing: IconButton(icon: const Icon(Icons.delete_outline), onPressed: () => setState(() => _schedule.removeAt(e.key))),
              ),
            ),
            OutlinedButton.icon(
              onPressed: () async {
                final s = await _twoFieldDialog(context, 'Add agenda item', 'Time (e.g. 7:30 PM)', 'Activity');
                if (s != null) setState(() => _schedule.add(ScheduleItem(time: s.$1, title: s.$2)));
              },
              icon: const Icon(Icons.add),
              label: const Text('Add agenda item'),
            ),

            section('Vendors'),
            SwitchListTile(contentPadding: EdgeInsets.zero, title: const Text('Accept vendor applications'), value: _acceptsVendors, onChanged: (v) => setState(() => _acceptsVendors = v)),
            if (_acceptsVendors) ...[
              SwitchListTile(contentPadding: EdgeInsets.zero, title: const Text('Student-run booths only'), subtitle: const Text('Current APU policy'), value: _studentVendorsOnly, onChanged: (v) => setState(() => _studentVendorsOnly = v)),
              TextFormField(controller: _vendorFee, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'Vendor fee (RM)')),
              const SizedBox(height: 12),
              TextFormField(controller: _vendorFacilities, decoration: const InputDecoration(labelText: 'Facilities provided (comma separated)', hintText: 'Table, 2 chairs, power socket')),
              const SizedBox(height: 12),
              TextFormField(controller: _vendorRequirements, maxLines: 2, decoration: const InputDecoration(labelText: 'Participation requirements', alignLabelWithHint: true)),
              const SizedBox(height: 10),
              Text('Allowed product categories', style: theme.textTheme.labelLarge),
              const SizedBox(height: 6),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: kProductCategories.map((c) {
                  final sel = _allowedCategories.contains(c);
                  return FilterChip(
                    label: Text(c),
                    selected: sel,
                    labelStyle: TextStyle(color: sel ? AppColors.white : AppColors.midnight),
                    onSelected: (s) => setState(() => s ? _allowedCategories.add(c) : _allowedCategories.remove(c)),
                  );
                }).toList(),
              ),
            ],

            const SizedBox(height: 28),
            BusyButton(label: _existing == null ? 'Publish event' : 'Save changes', icon: Icons.check, busy: _saving, onPressed: _save),
          ],
        ),
      ),
    );
  }

  Future<(String, String)?> _twoFieldDialog(BuildContext context, String title, String aLabel, String bLabel) async {
    final a = TextEditingController();
    final b = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: a, decoration: InputDecoration(labelText: aLabel), autofocus: true),
            const SizedBox(height: 10),
            TextField(controller: b, decoration: InputDecoration(labelText: bLabel)),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(ctx, a.text.trim().isNotEmpty), child: const Text('Add')),
        ],
      ),
    );
    if (ok != true) return null;
    return (a.text.trim(), b.text.trim());
  }
}

class _DateTile extends StatelessWidget {
  const _DateTile({required this.label, required this.value, required this.onTap});
  final String label;
  final DateTime value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: InputDecorator(
        decoration: InputDecoration(labelText: label, suffixIcon: const Icon(Icons.schedule, size: 18)),
        child: Text('${Fmt.shortDate(value)}, ${Fmt.time(value)}', style: const TextStyle(fontWeight: FontWeight.w600)),
      ),
    );
  }
}
