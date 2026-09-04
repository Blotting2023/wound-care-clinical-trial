import 'package:flutter/material.dart';

/// Clock-face direction + depth input for sinus tracts and undermining
class TunnelInputWidget extends StatefulWidget {
  final Function(int direction, double depth) onAdd;
  const TunnelInputWidget({super.key, required this.onAdd});

  @override
  State<TunnelInputWidget> createState() => _TunnelInputWidgetState();
}

class _TunnelInputWidgetState extends State<TunnelInputWidget> {
  int? _direction;
  final _depthCtrl = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Tunneling / Undermining', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<int>(
                    key: ValueKey(_direction),
                    initialValue: _direction,
                    decoration: const InputDecoration(labelText: 'Clock Direction'),
                    items: List.generate(12, (i) => DropdownMenuItem(value: i + 1, child: Text('${i + 1}:00'))),
                    onChanged: (v) => setState(() => _direction = v),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _depthCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Depth (cm)', suffixText: 'cm'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: ElevatedButton.icon(
                icon: const Icon(Icons.add),
                label: const Text('Add'),
                onPressed: (_direction != null && _depthCtrl.text.isNotEmpty)
                    ? () {
                        widget.onAdd(_direction!, double.parse(_depthCtrl.text));
                        _depthCtrl.clear();
                        setState(() => _direction = null);
                      }
                    : null,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _depthCtrl.dispose();
    super.dispose();
  }
}
