/*
 * This file is part of budgie-haste-applet
 *
 * Copyright (C) 2017 Stefan Ric <stfric369@gmail.com>
 *
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; either version 2 of the License, or
 * (at your option) any later version.
 */

using HasteApplet.Backend;
using HasteApplet.Widgets;
using HasteApplet.Views;

namespace HasteApplet.Views
{

[GtkTemplate (ui = "/com/github/cybre/budgie-haste-applet/ui/history_view.ui")]
private class HistoryView : Gtk.Box
{
    [GtkChild]
    private Gtk.Box? content_box;

    [GtkChild]
    private Gtk.Button? clear_all_button;

    private static HistoryView? _instance = null;
    private static Gtk.Clipboard? clipboard = null;
    private AutomaticScrollBox history_scrollbox;
    public Gtk.ListBox history_listbox;
    private static GLib.Settings settings;

    public HistoryView()
    {
        HistoryView._instance = this;

        // Initialise our clipboard
        clipboard = Gtk.Clipboard.get_for_display(this.get_display(), Gdk.SELECTION_CLIPBOARD);

        settings = BackendUtil.settings_manager.get_settings();

        history_listbox = new Gtk.ListBox();
        history_listbox.set_selection_mode(Gtk.SelectionMode.NONE);
        history_listbox.set_placeholder(construct_placeholder());

        history_scrollbox = new AutomaticScrollBox(null, null);
        content_box.pack_start(history_scrollbox, true, true, 0);
        history_scrollbox.add(history_listbox);
        history_scrollbox.max_height = 265;
        history_scrollbox.set_policy(Gtk.PolicyType.NEVER, Gtk.PolicyType.AUTOMATIC);

        populate_history.begin();

        if (history_listbox.get_children().length() == 0) {
            clear_all_button.set_sensitive(false);
        }

        BackendUtil.uploader.upload_started.connect(() => {
            clear_all_button.set_sensitive(false);
        });

        BackendUtil.uploader.upload_finished.connect(() => {
            clear_all_button.set_sensitive(true);
        });
    }

    private async void populate_history()
    {
        GLib.Variant history_list = settings.get_value("history");
        int64 timestamp;
        string title, data, uri;
        for (int i = 0; i<history_list.n_children(); i++) {
            history_list.get_child(i, "(xsss)", out timestamp, out title, out data, out uri);
            if (data != "") {
                add_to_history.begin(timestamp, title, data, uri, true);
            }
        }
    }

    private Gtk.Box construct_placeholder()
    {
        Gtk.Builder builder = new Gtk.Builder.from_resource("/com/github/cybre/budgie-haste-applet/ui/history_placeholder.ui");
        Gtk.Box history_placeholder = builder.get_object("history_placeholder") as Gtk.Box;

        return history_placeholder;
    }

    [GtkCallback]
    private void open_settings() {
        MainStack.set_page("settings_view");
    }

    [GtkCallback]
    private void add_new() {
        EditorView.get_instance().show_save_button(false);
        MainStack.set_page("editor_view");
    }

    [GtkCallback]
    private void clear_all() {
        settings.reset("history");
        foreach (Gtk.Widget widget in history_listbox.get_children()) {
            widget.destroy();
        }
        clear_all_button.set_sensitive(false);
    }

    public async void add_to_history(int64 timestamp, string title, string data, string uri = "", bool startup = false)
    {
        string new_title = title;
        if (new_title == "") {
            new_title = _("Untitled");
        }

        Widgets.HistoryItem history_item = new Widgets.HistoryItem(timestamp, new_title, data, uri, startup);

        if (history_listbox.get_children().length() == 0) {
            clear_all_button.set_sensitive(true);
            history_item.separator.set_no_show_all(true);
            history_item.separator.hide();
        }

        history_listbox.prepend(history_item);
        history_item.get_parent().set_can_focus(false);

        if (!startup) {
            save_item.begin(timestamp, new_title, data, uri);
        }

        history_item.deletion.connect((only_item) => {
            if (!only_item) {
                GLib.Timeout.add(50, () => {
                    uint n = history_listbox.get_children().length();
                    Gtk.ListBoxRow row = history_listbox.get_children().nth_data(n - 1) as Gtk.ListBoxRow;
                    HistoryItem item = row.get_child() as HistoryItem;
                    item.separator.set_no_show_all(true);
                    item.separator.hide();
                    return false;
                });
            } else {
                clear_all_button.set_sensitive(false);
            }
        });
    }

    private async void save_item(int64 timestamp, string title, string data, string uri)
    {
        GLib.Variant history_list = settings.get_value("history");

        GLib.Variant[]? history_variant_list = null;
        for (int i=0; i<history_list.n_children(); i++) {
            GLib.Variant history_variant = history_list.get_child_value(i);
            history_variant_list += history_variant;
        }

        GLib.Variant[] variant_array = {
            new GLib.Variant.int64(timestamp),
            new GLib.Variant.string(title),
            new GLib.Variant.string(data),
            new GLib.Variant.string(uri)
        };

        GLib.Variant history_entry_tuple = new GLib.Variant.tuple(variant_array);
        history_variant_list += history_entry_tuple;
        GLib.Variant history_entry_array = new GLib.Variant.array(null, history_variant_list);
        settings.set_value("history", history_entry_array);
    }

    public static void copy_uri(string uri) {
        clipboard.set_text(uri, -1);
    }

    public static unowned HistoryView? get_instance() {
        return _instance;
    }
}

} // End namespace