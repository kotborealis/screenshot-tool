/***

    Copyright (C) 2014-2016 Fabio Zaramella <ffabio.96.x@gmail.com>

    This program is free software: you can redistribute it and/or modify it
    under the terms of the GNU Lesser General Public License version 3, as
    published by the Free Software Foundation.

    This program is distributed in the hope that it will be useful, but
    WITHOUT ANY WARRANTY; without even the implied warranties of
    MERCHANTABILITY, SATISFACTORY QUALITY, or FITNESS FOR A PARTICULAR
    PURPOSE.  See the GNU General Public License for more details.

    You should have received a copy of the GNU General Public License along
    with this program.  If not, see <http://www.gnu.org/licenses>

***/

namespace Screenshot {

    public class ScreenshotApp : Granite.Application {

        private static ScreenshotApp app;
        private ScreenshotWindow window = null;

        private new OptionEntry[] options;

        private int action = 0;
        private int delay = 1;
        private bool grab_pointer = false;
        private bool screen = false;
        private bool win = false;
        private bool area = false;
        private bool redact = false;
        private bool clipboard = false;
        private bool upload = false;

        construct {
            flags |= ApplicationFlags.HANDLES_COMMAND_LINE;

            options = new OptionEntry[8];
            options[0] = { "window", 'w', 0, OptionArg.NONE, ref win, _("Capture active window"), null };
            options[1] = { "area", 'r', 0, OptionArg.NONE, ref area, _("Capture area"), null };
            options[2] = { "screen", 's', 0, OptionArg.NONE, ref screen, _("Capture the whole screen"), null };
            options[3] = { "delay", 'd', 0, OptionArg.INT, ref delay, _("Take screenshot after specified delay"), _("Seconds")};
            options[4] = { "grab-pointer", 'p', 0, OptionArg.NONE, ref grab_pointer, _("Include the pointer with the screenshot"), null };
            options[5] = { "redact", 'e', 0, OptionArg.NONE, ref redact, _("Redact system text"), null };
            options[6] = { "clipboard", 'c', 0, OptionArg.NONE, ref clipboard, _("Save screenshot to clipboard"), null };
            options[7] = { "upload", 'u', 0, OptionArg.NONE, ref upload, _("Upload screenshot to imgur"), null };

            add_main_option_entries (options);

            // App info
            build_version = Build.VERSION;
            build_data_dir = Build.DATADIR;
            build_pkg_data_dir = Build.PKGDATADIR;
            build_release_name = Build.RELEASE_NAME;
            build_version_info = Build.VERSION_INFO;

            program_name = _("Screenshot");
            exec_name = "screenshot";

            app_years = "2014-2017";
            application_id = "net.launchpad.screenshot";
            app_icon = "accessories-screenshot";
            app_launcher = "screenshot.desktop";

            main_url = "https://github.com/elementary/screenshot-tool";
            bug_url = "https://github.com/elementary/screenshot-tool/issues";
            help_url = "https://elementaryos.stackexchange.com/questions/tagged/screenshot";
            translate_url = "https://l10n.elementary.io/projects/screenshot-tool";

            about_authors = {"Fabio Zaramella <ffabio.96.x@gmail.com>"};
            about_documenters = {"Fabio Zaramella <ffabio.96.x@gmail.com>"};
            about_artists = {"Fabio Zaramella"};
            about_comments = _("Save images of your screen or individual windows.");
            about_translators = _("translator-credits");
            about_license_type = Gtk.License.GPL_3_0;

            var quit_action = new SimpleAction ("quit", null);
            quit_action.activate.connect (() => {
                if (window != null) {
                    window.destroy ();
                }
            });

            add_action (quit_action);
            add_accelerator ("<Control>q", "app.quit", null);
        }

        protected override void activate () {
            this.hold ();
            stdout.printf ("activated\n");
            this.release ();
        }

        private void normal_startup () {
            if (window != null) {
                window.present (); // present window if app is already open
                return;
            }

            window = new ScreenshotWindow ();
            window.set_application (this);
            window.show_all ();
        }

        public static ScreenshotApp get_instance () {
            if (app == null) {
                app = new ScreenshotApp ();
            }

            return app;
        }

        public static int main (string[] args) {
            // Init internationalization support
            Intl.setlocale (LocaleCategory.ALL, "");
            Intl.bind_textdomain_codeset (Build.GETTEXT_PACKAGE, "UTF-8");
            Intl.textdomain (Build.GETTEXT_PACKAGE);

            Gtk.init (ref args);
            Gtk.Settings.get_default ().gtk_application_prefer_dark_theme = true;

            app = new ScreenshotApp ();

            //Workaround to get Granite's --about & Gtk's --help working together
            if ("--help" in args || "-h" in args) {
                return ((Gtk.Application)app).run (args);
            } else {
                return app.run (args);
            }
        }

        private int _command_line (ApplicationCommandLine command_line) {
            string[] args = command_line.get_arguments ();

            try {
                var opt_context = new OptionContext ("- Screenshot tool");
                opt_context.set_help_enabled (true);
                opt_context.add_main_entries (options, null);

                unowned string[] tmp = args;
                opt_context.parse (ref tmp);
            } catch (OptionError e) {
                command_line.print ("error: %s\n", e.message);
                command_line.print ("Run '%s --help' to see a full list of available command line options.\n", args[0]);
                return 0;
            }

            if (screen) action = 1;
            if (win) action = 2;
            if (area) action = 3;

            if (action == 0) {
                normal_startup ();
            } else {
                window = new ScreenshotWindow.from_cmd (action, delay, grab_pointer, redact, clipboard, upload);
                window.set_application (this);
                window.take_clicked ();
            }

            return 0;
        }

        public override int command_line (ApplicationCommandLine commmand_line) {
            this.hold ();
            int res = _command_line (commmand_line);
            this.release ();

            return res;
        }

        public static void show_error_dialog (string? text = null, string? text2 = null) {
            var dialog = new Gtk.MessageDialog (null, Gtk.DialogFlags.MODAL, Gtk.MessageType.ERROR,
                                                Gtk.ButtonsType.CLOSE, _(text ?? "Could not capture screenshot"));
            dialog.secondary_text = _(text2 ?? "Image not saved");
            dialog.deletable = false;
            dialog.run ();
            dialog.destroy ();
        }

        public static string? upload_image (Gdk.Pixbuf image){
            string? link = null;
            try{
                string tmp_file;

                GLib.Process.spawn_command_line_sync("mktemp '/tmp/i-XXXXXXX.png'", out tmp_file);

                tmp_file = tmp_file.replace("\n", "");
                image.save(tmp_file, "png");

                string cmd_curl = "curl -sH \"Authorization: Client-ID %s\" -F \"image=@%s\" \"https://api.imgur.com/3/upload\"";
                string curl_stdout;

                GLib.Process.spawn_command_line_sync(cmd_curl.printf("3e7a4deb7ac67da", tmp_file), out curl_stdout);

                GLib.MatchInfo m;
                var link_regex = new Regex(".*\"link\":\"([^\"]*)\".*");
                link_regex.match(curl_stdout, 0, out m);
                link = m.fetch(1).replace("\\/", "/");
                //Gtk.Clipboard.get_default(this.get_display()).set_text(link, link.length);    
            }
            catch(GLib.Error e){
                show_error_dialog ("Failed to save temp file");
                debug (e.message);
            }
            catch(GLib.SpawnError e){
                show_error_dialog ("Failed to upload image");
                debug (e.message);
            }
            catch(RegexError e){
                show_error_dialog ("Failed to upload image");
                debug (e.message);
            }
            return link;
        }
    }
}
