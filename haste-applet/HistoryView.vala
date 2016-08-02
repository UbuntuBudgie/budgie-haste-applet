/*
 * This file is part of haste-applet
 *
 * Copyright (C) 2016 Stefan Ric <stfric369@gmail.com>
 *
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; either version 2 of the License, or
 * (at your option) any later version.
 */

namespace HasteApplet
{
    public class HistoryView : Gtk.Box
    {
        private Gtk.Box history_header_sub_box;
        private Gtk.Box history_header_box;
        private Gtk.Box placeholder_box;
        private Gtk.Box clear_all_box;
        private Gtk.Label placeholder_label;
        private Gtk.Label history_header_label;
        public Gtk.Button history_add_button;
        private Gtk.Button clear_all_button;
        private Gtk.Image placeholder_image;
        private GLib.Settings settings;
        private Gtk.Clipboard clipboard;
        private AutomaticScrollBox history_scroller;
        private HistoryViewItem history_view_item;
        public Gtk.ListBox history_listbox;

        public HistoryView(GLib.Settings settings, Gtk.Clipboard clipboard)
        {
            Object(spacing: 0, orientation: Gtk.Orientation.VERTICAL);
            width_request = 300;
            height_request = -1;

            this.settings = settings;
            this.clipboard = clipboard;

            history_header_label = new Gtk.Label("<span font=\"11\">Recent Hastes</span>");
            history_header_label.use_markup = true;
            history_header_label.halign = Gtk.Align.START;
            history_header_label.get_style_context().add_class("dim-label");

            history_add_button = new Gtk.Button.with_label("Add");
            history_add_button.tooltip_text = "Add a new haste";
            history_add_button.can_focus = false;

            Gtk.Separator separator = new Gtk.Separator(Gtk.Orientation.HORIZONTAL);

            history_header_sub_box = new Gtk.Box(Gtk.Orientation.HORIZONTAL, 0);
            history_header_sub_box.margin = 10;
            history_header_sub_box.pack_start(history_header_label, true, true, 0);
            history_header_sub_box.pack_start(history_add_button, false, false, 0);

            history_header_box = new Gtk.Box(Gtk.Orientation.VERTICAL, 0);
            history_header_box.pack_start(history_header_sub_box, true, true, 0);
            history_header_box.pack_start(separator, true, true, 0);

            history_listbox = new Gtk.ListBox();
            history_listbox.selection_mode = Gtk.SelectionMode.NONE;
            history_scroller = new AutomaticScrollBox(null, null);
            history_scroller.max_height = 265;
            history_scroller.set_policy(Gtk.PolicyType.NEVER, Gtk.PolicyType.AUTOMATIC);
            history_scroller.add(history_listbox);

            clear_all_button = new Gtk.Button.with_label("Clear all Hastes");
            ((Gtk.Label) clear_all_button.get_child()).halign = Gtk.Align.START;
            clear_all_button.get_child().margin = 5;
            clear_all_button.get_child().margin_start = 0;
            clear_all_button.clicked.connect(clear_all);
            clear_all_button.can_focus = false;
            clear_all_button.relief = Gtk.ReliefStyle.NONE;

            clear_all_box = new Gtk.Box(Gtk.Orientation.VERTICAL, 0);
            clear_all_box.pack_start(new Gtk.Separator(Gtk.Orientation.HORIZONTAL), false, false, 0);
            clear_all_box.pack_end(clear_all_button, false, true, 0);

            placeholder_image = new Gtk.Image.from_icon_name(
                "action-unavailable-symbolic", Gtk.IconSize.DIALOG);
            placeholder_image.pixel_size = 64;
            placeholder_label = new Gtk.Label("<big>Nothing to see here</big>");
            placeholder_label.use_markup = true;
            placeholder_box = new Gtk.Box(Gtk.Orientation.VERTICAL, 6);
            placeholder_box.margin = 40;
            placeholder_box.get_style_context().add_class("dim-label");
            placeholder_box.halign = Gtk.Align.CENTER;
            placeholder_box.valign = Gtk.Align.CENTER;
            placeholder_box.pack_start(placeholder_image, false, false, 6);
            placeholder_box.pack_start(placeholder_label, false, false, 0);

            history_listbox.set_placeholder(placeholder_box);
            placeholder_box.show_all();

            pack_start(history_header_box, false, false, 0);
            pack_start(history_scroller, true, true, 0);
            pack_start(clear_all_box, true, true, 0);
            show_all();

            update_child_count();
        }

        public void update_child_count()
        {
            uint len = history_listbox.get_children().length();

            if (len == 0) {
                clear_all_button.sensitive = false;
            } else {
                clear_all_button.sensitive = true;
            }
        }

        public async void update_history(int n, bool startup)
        {
            Gtk.ListBoxRow? separator_item = null;
            if (history_listbox.get_children().length() != 0) {
                Gtk.Separator separator = new Gtk.Separator(Gtk.Orientation.HORIZONTAL);
                separator.can_focus = false;
                separator_item = new Gtk.ListBoxRow();
                separator_item.selectable = false;
                separator_item.can_focus = false;
                separator_item.activatable = false;
                separator_item.add(separator);
                history_listbox.prepend(separator_item);
            }

            history_view_item = new HistoryViewItem(n, settings);
            history_listbox.prepend(history_view_item);

            Gtk.ListBoxRow parent = (Gtk.ListBoxRow) history_view_item.get_parent();
            parent.selectable = false;
            parent.can_focus = false;
            parent.activatable = false;

            history_listbox.show_all();

            if (startup) {
                history_view_item.reveal_child = true;
            } else {
                history_view_item.transition_type = Gtk.RevealerTransitionType.SLIDE_UP;
                GLib.Timeout.add(1, () => {
                    history_view_item.reveal_child = true;
                    return true;
                });
            }

            history_view_item.copy.connect((url) => {
                clipboard.set_text("http://%s".printf(url), -1);
            });

            history_view_item.deletion.connect(() => {
                int index = parent.get_index();

                if (history_listbox.get_children().length() == 1) {
                    parent.destroy();
                    update_child_count();
                    return;
                }

                if (index == 0) {
                    Gtk.Widget row_after = history_listbox.get_row_at_index(index + 1);
                    if (row_after != null) row_after.destroy();
                } else {
                    Gtk.Widget row_before = history_listbox.get_row_at_index(index - 1);
                    if (row_before != null) row_before.destroy();
                }

                update_child_count();
            });

            update_child_count();
        }

        public void add_to_history(string link, string title)
        {
            GLib.Variant history_list = settings.get_value("history");

            GLib.DateTime datetime = new GLib.DateTime.now_local();
            int64 timestamp = datetime.to_unix();
            if (title == "") title = "Untitled";

            GLib.Variant timestamp_variant = new GLib.Variant.int64(timestamp);
            GLib.Variant title_variant = new GLib.Variant.string(title);
            GLib.Variant link_variant = new GLib.Variant.string(link);

            GLib.Variant[]? history_variant_list = null;
            for (int i=0; i<history_list.n_children(); i++) {
                GLib.Variant history_variant = history_list.get_child_value(i);
                history_variant_list += history_variant;
            }

            GLib.Variant history_entry_tuple = new GLib.Variant.tuple(
                {timestamp_variant, title_variant, link_variant});
            history_variant_list += history_entry_tuple;
            GLib.Variant history_entry_array = new GLib.Variant.array(null, history_variant_list);
            settings.set_value("history", history_entry_array);
            update_history(history_variant_list.length - 1, false);
        }

        public void clear_all()
        {
            settings.reset("history");
            foreach (Gtk.Widget child in history_listbox.get_children()) {
                child.destroy();
            }
            update_child_count();
        }
    }
}