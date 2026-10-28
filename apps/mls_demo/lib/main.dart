import 'dart:convert';
import 'package:flutter/material.dart';
import 'lab_controller.dart';

void main() => runApp(const MlsLabApp());

const ink = Color(0xFF173A36);
const accent = Color(0xFF176B58);

class MlsLabApp extends StatelessWidget {
  const MlsLabApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'MLS / Learning lab',
    debugShowCheckedModeBanner: false,
    theme: ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: accent,
        surface: const Color(0xFFF5F4EE),
      ),
      scaffoldBackgroundColor: const Color(0xFFF5F4EE),
      textTheme: const TextTheme(
        headlineLarge: TextStyle(
          fontSize: 42,
          fontWeight: FontWeight.w600,
          letterSpacing: -1.5,
          color: ink,
        ),
      ),
    ),
    home: const LabPage(),
  );
}

class LabPage extends StatefulWidget {
  const LabPage({super.key});
  @override
  State<LabPage> createState() => _LabPageState();
}

class _LabPageState extends State<LabPage> {
  late final LabController lab = LabController();
  final composer = TextEditingController();
  String sender = 'Alice';
  static const actions = [
    'Invite Bob',
    'Invite Charlie',
    'Exchange messages',
    'Update Bob’s keys',
    'Remove Bob + test access',
  ];
  @override
  void dispose() {
    lab.dispose();
    composer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: lab,
    builder: (context, _) => Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.all(
            MediaQuery.sizeOf(context).width < 600 ? 16 : 28,
          ),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1120),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.hub_outlined, color: accent),
                      const SizedBox(width: 10),
                      const Expanded(
                        child: Text(
                          'MLS / LEARNING LAB',
                          style: TextStyle(
                            letterSpacing: 2,
                            fontWeight: FontWeight.w700,
                            color: ink,
                          ),
                        ),
                      ),
                      TextButton.icon(
                        onPressed: lab.reset,
                        icon: const Icon(Icons.restart_alt),
                        label: const Text('Reset lab'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 32),
                  Text(
                    'One group.\nAn evolving secret.',
                    style: Theme.of(context).textTheme.headlineLarge,
                  ),
                  const SizedBox(height: 14),
                  const Text(
                    'Three independent users. Real OpenMLS encryption. A relay that lives entirely on this device.',
                    style: TextStyle(fontSize: 16, color: ink),
                  ),
                  const SizedBox(height: 28),
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      for (final name in lab.clients.keys) _userCard(name),
                    ],
                  ),
                  const SizedBox(height: 24),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(22),
                    decoration: BoxDecoration(
                      color: ink,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'GUIDED EXPERIMENT  /  ${lab.step.clamp(0, 5)} OF 5',
                          style: const TextStyle(
                            color: Color(0xFFA4D5BD),
                            letterSpacing: 2,
                            fontSize: 11,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          lab.step < 5
                              ? actions[lab.step]
                              : 'Bob has the ciphertext. He does not have the new keys.',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 23,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Wrap(
                          spacing: 12,
                          runSpacing: 12,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            FilledButton.icon(
                              onPressed: lab.step < 5 ? lab.next : null,
                              style: FilledButton.styleFrom(
                                backgroundColor: const Color(0xFFD4F1B4),
                                foregroundColor: ink,
                                disabledForegroundColor: const Color(
                                  0xFFDBE9E4,
                                ),
                                disabledBackgroundColor: const Color(
                                  0xFF385A53,
                                ),
                              ),
                              icon: const Icon(Icons.arrow_forward),
                              label: Text(
                                lab.step < 5
                                    ? 'Run next step'
                                    : 'Experiment complete',
                              ),
                            ),
                            const Text(
                              'Expand any wire event to inspect its bytes.',
                              style: TextStyle(color: Color(0xFFBBD0CA)),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  if (lab.error != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: Text(
                        lab.error!,
                        style: const TextStyle(color: Colors.red),
                      ),
                    ),
                  if (lab.step >= 2) ...[
                    const SizedBox(height: 24),
                    Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        DropdownButton<String>(
                          value: effectiveSender,
                          items: ['Alice', if (lab.step < 5) 'Bob', 'Charlie']
                              .map(
                                (name) => DropdownMenuItem(
                                  value: name,
                                  child: Text(name),
                                ),
                              )
                              .toList(),
                          onChanged: (value) => setState(() => sender = value!),
                        ),
                        SizedBox(
                          width: MediaQuery.sizeOf(context).width < 600
                              ? MediaQuery.sizeOf(context).width - 32
                              : 340,
                          child: TextField(
                            controller: composer,
                            decoration: const InputDecoration(
                              border: OutlineInputBorder(),
                              labelText: 'Write an encrypted message',
                            ),
                            onSubmitted: (_) => _send(),
                          ),
                        ),
                        FilledButton(
                          onPressed: _send,
                          child: const Text('Encrypt & send'),
                        ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 30),
                  Row(
                    children: [
                      const Expanded(
                        child: Text(
                          'Protocol journal',
                          style: TextStyle(
                            fontSize: 23,
                            fontWeight: FontWeight.w600,
                            color: ink,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        '${lab.events.length} events',
                        style: const TextStyle(color: accent),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  for (final event in lab.events.reversed) _event(event),
                  const SizedBox(height: 20),
                  const Text(
                    'Learning scope: basic identities are labels, not verified people. State is in memory. '
                    'The key update illustrates the MLS recovery mechanism; it does not simulate an attacker. '
                    'A removed member may still know earlier plaintext. No server or keystore is used.',
                    style: TextStyle(color: Color(0xFF64716D), height: 1.5),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  );
  String get effectiveSender =>
      lab.step >= 5 && sender == 'Bob' ? 'Alice' : sender;

  void _send() {
    lab.send(effectiveSender, composer.text);
    composer.clear();
  }

  Widget _userCard(String name) {
    final state = lab.state(name);
    final active = state?.active ?? false;
    return Container(
      width: 260,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFDFE4DA)),
      ),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: active
                ? const Color(0xFFDDEBDC)
                : const Color(0xFFEEEDE8),
            child: Text(name[0], style: const TextStyle(color: ink)),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  state == null
                      ? 'Waiting for Welcome'
                      : active
                      ? 'Member · epoch ${state.epoch}'
                      : 'Removed · old state',
                  style: TextStyle(color: active ? accent : Colors.brown),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _event(LabEvent event) => Card(
    margin: const EdgeInsets.only(bottom: 8),
    elevation: 0,
    color: event.blocked ? const Color(0xFFFFE9DB) : Colors.white,
    child: ExpansionTile(
      shape: const Border(),
      leading: Icon(
        event.blocked
            ? Icons.lock_outline
            : event.wire != null
            ? Icons.code
            : Icons.check_circle_outline,
        color: event.blocked ? Colors.brown : accent,
      ),
      title: Text(
        event.title,
        style: const TextStyle(fontWeight: FontWeight.w600),
      ),
      subtitle: Padding(
        padding: const EdgeInsets.only(top: 4),
        child: Text(event.detail),
      ),
      children: [
        Padding(
          padding: const EdgeInsets.all(20),
          child: Align(
            alignment: Alignment.centerLeft,
            child: SelectableText(
              event.wire == null
                  ? event.detail
                  : 'MLS wire message · ${event.wire!.length} bytes\n\n${base64Encode(event.wire!)}',
              style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
            ),
          ),
        ),
      ],
    ),
  );
}
