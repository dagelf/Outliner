/*
* Copyright (c) 2018 (https://github.com/phase1geo/Outliner)
*
* This program is free software; you can redistribute it and/or
* modify it under the terms of the GNU General Public
* License as published by the Free Software Foundation; either
* version 2 of the License, or (at your option) any later version.
*
* This program is distributed in the hope that it will be useful,
* but WITHOUT ANY WARRANTY; without even the implied warranty of
* MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
* General Public License for more details.
*
* You should have received a copy of the GNU General Public
* License along with this program; if not, write to the
* Free Software Foundation, Inc., 51 Franklin Street, Fifth Floor,
* Boston, MA 02110-1301 USA
*
* Authored by: Trevor Williams <phase1geo@gmail.com>
*/

using Gtk;

public enum TabAddReason {
  NEW,
  OPEN,
  IMPORT,
  LOAD
}

public class MainWindow : ApplicationWindow {

  private const string DESKTOP_SCHEMA = "io.elementary.desktop";
  private const string DARK_KEY       = "prefer-dark";

  private GLib.Settings   _settings;
  private HeaderBar?      _header         = null;
  private DynamicNotebook _nb;
  private Document?       _doc            = null;
  private Revealer?       _inspector      = null;
  // private NodeInspector  _node_inspector = null;
  private Stack?         _stack          = null;
  private Popover?       _search         = null;
  private MenuButton?    _search_btn     = null;
  private SearchEntry?   _search_entry   = null;
  private TreeView       _search_list;
  private Gtk.ListStore  _search_items;
  private ScrolledWindow _search_scroll;
  private CheckButton    _search_titles;
  private CheckButton    _search_notes;
  private CheckButton    _search_folded;
  private CheckButton    _search_unfolded;
  private CheckButton    _search_tasks;
  private CheckButton    _search_nontasks;
  private Popover?       _export         = null;
  private Button?        _undo_btn       = null;
  private Button?        _redo_btn       = null;
  private Button?        _indent         = null;
  private Button?        _unindent       = null;
  private Button?        _prop_btn       = null;
  private Image?         _prop_show      = null;
  private Image?         _prop_hide      = null;
  private bool           _debug          = false;
  private bool           _prefer_dark    = false;

  private const GLib.ActionEntry[] action_entries = {
    { "action_new",           action_new },
    { "action_open",          action_open },
    { "action_save",          action_save },
    { "action_save_as",       action_save_as },
    { "action_undo",          action_undo },
    { "action_redo",          action_redo },
    { "action_search",        action_search },
    { "action_quit",          action_quit },
    { "action_export",        action_export },
    { "action_print",         action_print }
  };

  private delegate void ChangedFunc();

  public signal void canvas_changed( OutlineTable? ot );

  /* Create the main window UI */
  public MainWindow( Gtk.Application app, GLib.Settings settings ) {

    Object( application: app );

    _settings = settings;

    var window_x = settings.get_int( "window-x" );
    var window_y = settings.get_int( "window-y" );
    var window_w = settings.get_int( "window-w" );
    var window_h = settings.get_int( "window-h" );

    /* Create the header bar */
    _header = new HeaderBar();
    _header.set_show_close_button( true );

    /* Set the main window data */
    title = _( "Outliner" );
    if( (window_x == -1) && (window_y == -1) ) {
      set_position( Gtk.WindowPosition.CENTER );
    } else {
      move( window_x, window_y );
    }
    set_default_size( window_w, window_h );
    set_titlebar( _header );
    set_border_width( 2 );
    destroy.connect( Gtk.main_quit );

    /* Set the stage for menu actions */
    var actions = new SimpleActionGroup ();
    actions.add_action_entries( action_entries, this );
    insert_action_group( "win", actions );

    /* Add keyboard shortcuts */
    add_keyboard_shortcuts( app );

    _nb = new DynamicNotebook();
    _nb.add_button_visible = false;
    _nb.tab_bar_behavior   = DynamicNotebook.TabBarBehavior.SINGLE;
    _nb.tab_switched.connect( tab_switched );
    _nb.tab_reordered.connect( tab_reordered );
    _nb.close_tab_requested.connect( close_tab_requested );

    /* Create title toolbar */
    var new_btn = new Button.from_icon_name( "document-new", IconSize.LARGE_TOOLBAR );
    new_btn.set_tooltip_markup( _( "New File   <i>(Control-N)</i>" ) );
    new_btn.clicked.connect( do_new_file );
    _header.pack_start( new_btn );

    var open_btn = new Button.from_icon_name( "document-open", IconSize.LARGE_TOOLBAR );
    open_btn.set_tooltip_markup( _( "Open File   <i>(Control-O)</i>" ) );
    open_btn.clicked.connect( do_open_file );
    _header.pack_start( open_btn );

    var save_btn = new Button.from_icon_name( "document-save-as", IconSize.LARGE_TOOLBAR );
    save_btn.set_tooltip_markup( _( "Save File As   <i>(Control-Shift-S)</i>" ) );
    save_btn.clicked.connect( do_save_as_file );
    _header.pack_start( save_btn );

    _undo_btn = new Button.from_icon_name( "edit-undo", IconSize.LARGE_TOOLBAR );
    _undo_btn.set_tooltip_markup( _( "Undo   <i>(Control-Z)</i>" ) );
    _undo_btn.set_sensitive( false );
    _undo_btn.clicked.connect( do_undo );
    _header.pack_start( _undo_btn );

    _redo_btn = new Button.from_icon_name( "edit-redo", IconSize.LARGE_TOOLBAR );
    _redo_btn.set_tooltip_markup( _( "Redo   <i>(Control-Shift-Z)</i>" ) );
    _redo_btn.set_sensitive( false );
    _redo_btn.clicked.connect( do_redo );
    _header.pack_start( _redo_btn );

    _indent = new Button.from_icon_name( "format-indent-more", IconSize.LARGE_TOOLBAR );
    _indent.set_tooltip_markup( _( "Indent  <i>Tab</i>" ) );
    //_indent.set_sensitive( false );
    _indent.clicked.connect( do_indent );
    _header.pack_start( _indent );

    _unindent = new Button.from_icon_name( "format-indent-less", IconSize.LARGE_TOOLBAR );
    _unindent.set_tooltip_markup( _( "Unindent  <i>Shift-Tab</i>" ) );
    // _unindent.set_sensitive( false );
    _unindent.clicked.connect( do_unindent );
    _header.pack_start( _unindent );

    /* Add the buttons on the right side in the reverse order */
    add_property_button();
    add_export_button();
    add_search_button();

    /* Display the UI */
    add( _nb );
    show_all();

  }

  /* Returns the current drawing area */
  public OutlineTable? get_current_table( string? caller = null ) {
    if( _debug && (caller != null) ) {
      stdout.printf( "get_current_table called from %s\n", caller );
    }
    if( _nb.current == null ) { return( null ); }
    var bin1 = (Gtk.Bin)_nb.current.page;
    var bin2 = bin1.get_child() as Gtk.Bin;
    return( bin2.get_child() as OutlineTable );
  }

  /* Handles any changes to the dark mode preference gsettings for the desktop */
  private void handle_prefer_dark_changes() {
    var lookup = SettingsSchemaSource.get_default().lookup( DESKTOP_SCHEMA, false );
    if( lookup != null ) {
      var desktop_settings = new GLib.Settings( DESKTOP_SCHEMA );
      _prefer_dark = desktop_settings.get_boolean( DARK_KEY );
      desktop_settings.changed.connect(() => {
        _prefer_dark = desktop_settings.get_boolean( DARK_KEY );
        on_theme_changed( get_current_table( "handle_prefer_dark_changes" ) );
      });
    }
  }

  /* Updates the title */
  private void update_title( OutlineTable? ot ) {
    string suffix = " \u2014 Outliner";
    if( (ot == null) || !ot.document.is_saved() ) {
      _header.set_title( _( "Unnamed Document" ) + suffix );
    } else {
      _header.set_title( GLib.Path.get_basename( ot.document.filename ) + suffix );
    }

    if( (_doc == null) || !_doc.is_saved() ) {
      _header.set_title( _( "Unnamed Document" ) + suffix );
    } else {
      _header.set_title( GLib.Path.get_basename( _doc.filename ) + suffix );
    }
  }

  /* This needs to be called whenever the tab is changed */
  private void tab_changed( Tab tab ) {
    var bin1 = (Gtk.Bin)tab.page;
    var bin2 = bin1.get_child() as Gtk.Bin;
    var ot   = bin2.get_child() as OutlineTable;
    do_buffer_changed( ot );
    update_title( ot );
    canvas_changed( ot );
    save_tab_state( tab );
  }

  /* Called whenever the current tab is switched in the notebook */
  private void tab_switched( Tab? old_tab, Tab new_tab ) {
    tab_changed( new_tab );
  }

  /* Called whenever the current tab is moved to a new position */
  private void tab_reordered( Tab? tab, int new_pos ) {
    save_tab_state( tab );
  }

  /* Called whenever the user clicks on the close button and the tab is unnamed */
  private bool close_tab_requested( Tab tab ) {
    var bin1 = (Gtk.Bin)tab.page;
    var bin2 = bin1.get_child() as Gtk.Bin;
    var ot   = bin2.get_child() as OutlineTable;
    var ret  = ot.document.is_saved() || show_save_warning( ot );
    return( ret );
  }

   /* Adds a new tab to the notebook */
  public OutlineTable add_tab( string? fname, TabAddReason reason ) {

    /* Create and pack the canvas */
    var ot = new OutlineTable( _settings );
//    ot.current_changed.connect( on_current_changed );
//    ot.show_properties.connect( show_properties );
//    ot.hide_properties.connect( hide_properties );
    ot.map_event.connect( on_table_mapped );
    ot.undo_buffer.buffer_changed.connect( do_buffer_changed );
    ot.theme_changed.connect( on_theme_changed );

    if( fname != null ) {
      ot.document.filename = fname;
    }

    /* Create the overlay that will hold the canvas so that we can put an entry box for emoji support */
    var overlay = new Overlay();
    overlay.add( ot );

    /* Create the scrolled window for the treeview */
    var scroll = new ScrolledWindow( null, null );
    // scroll.height_request = 200;
    scroll.hscrollbar_policy = PolicyType.EXTERNAL;
    scroll.add( overlay );

    var tab = new Tab( ot.document.label, null, scroll );
    tab.pinnable = false;
    tab.tooltip  = fname;

    /* Add the page to the notebook */
    _nb.insert_tab( tab, _nb.n_tabs );

    /* Update the titlebar */
    update_title( ot );

    /* Make the drawing area new */
    if( reason == TabAddReason.NEW ) {
      ot.initialize_for_new();
    } else {
      ot.initialize_for_open();
    }

    /* Indicate that the tab has changed */
    if( reason != TabAddReason.LOAD ) {
      _nb.current = tab;
    }

    ot.grab_focus();

    return( ot );

  }

  /* Save the current tab state */
  private void save_tab_state( Tab current_tab ) {

    var dir = GLib.Path.build_filename( Environment.get_user_data_dir(), "outliner" );

    if( DirUtils.create_with_parents( dir, 0775 ) != 0 ) {
      return;
    }

    var       fname        = GLib.Path.build_filename( dir, "tab_state.xml" );
    var       selected_tab = -1;
    var       i            = 0;
    Xml.Doc*  doc          = new Xml.Doc( "1.0" );
    Xml.Node* root         = new Xml.Node( null, "tabs" );

    doc->set_root_element( root );

    _nb.tabs.foreach((tab) => {
      var       bin1  = (Gtk.Bin)tab.page;
      var       bin2  = bin1.get_child() as Gtk.Bin;
      var       table = bin2.get_child() as OutlineTable;
      Xml.Node* node  = new Xml.Node( null, "tab" );
      node->new_prop( "path",  table.document.filename );
      node->new_prop( "saved", table.document.is_saved().to_string() );
      root->add_child( node );
      if( tab == current_tab ) {
        selected_tab = i;
      }
      i++;
    });

    if( selected_tab > -1 ) {
      root->new_prop( "selected", selected_tab.to_string() );
    }

    /* Save the file */
    doc->save_format_file( fname, 1 );

    delete doc;

  }

  /* Loads the tab state */
  public bool load_tab_state() {

    var tab_state = GLib.Path.build_filename( Environment.get_user_data_dir(), "outliner", "tab_state.xml" );

    /* If the file does not exist, skip the rest and return false */
    if( !FileUtils.test( tab_state, FileTest.EXISTS ) ) return( false );

    Xml.Doc* doc = Xml.Parser.parse_file( tab_state );

    if( doc == null ) { return( false ); }

    var root = doc->get_root_element();
    for( Xml.Node* it = root->children; it != null; it = it->next ) {
      if( (it->type == Xml.ElementType.ELEMENT_NODE) && (it->name == "tab") ) {
        var fname = it->get_prop( "path" );
        var saved = it->get_prop( "saved" );
        var table = add_tab( fname, TabAddReason.LOAD );
        table.document.load_filename( fname, bool.parse( saved ) );
        table.document.load();
      }
    }

    var s = root->get_prop( "selected" );
    if( s != null ) {
      _nb.current = _nb.get_tab_by_index( int.parse( s ) );
      tab_changed( _nb.current );
    }

    delete doc;

    return( _nb.n_tabs > 0 );

  }

  /* Adds keyboard shortcuts for the menu actions */
  private void add_keyboard_shortcuts( Gtk.Application app ) {

    app.set_accels_for_action( "win.action_new",     { "<Control>n" } );
    app.set_accels_for_action( "win.action_open",    { "<Control>o" } );
    app.set_accels_for_action( "win.action_save",    { "<Control>s" } );
    app.set_accels_for_action( "win.action_save_as", { "<Control><Shift>s" } );
    app.set_accels_for_action( "win.action_undo",    { "<Control>z" } );
    app.set_accels_for_action( "win.action_redo",    { "<Control><Shift>z" } );
    app.set_accels_for_action( "win.action_search",  { "<Control>f" } );
    app.set_accels_for_action( "win.action_quit",    { "<Control>q" } );
    app.set_accels_for_action( "win.action_print",   { "<Control>p" } );

  }

  /* Adds the search functionality */
  private void add_search_button() {

    /* Create the menu button */
    _search_btn = new MenuButton();
    _search_btn.set_image( new Image.from_icon_name( "edit-find", IconSize.LARGE_TOOLBAR ) );
    _search_btn.set_tooltip_markup( _( "Search   <i>(Control-F)</i>" ) );
    _search_btn.clicked.connect( on_search_change );
    _header.pack_end( _search_btn );

    /* Create search popover */
    var box = new Box( Orientation.VERTICAL, 5 );

    /* Create the search entry field */
    _search_entry = new SearchEntry();
    _search_entry.placeholder_text = _( "Search Nodes" );
    _search_entry.width_chars = 40;
    _search_entry.search_changed.connect( on_search_change );

    _search_items = new Gtk.ListStore( 3, typeof(string), typeof(string), typeof(Node) );

    /* Create the treeview */
    _search_list  = new TreeView.with_model( _search_items );
    var type_cell = new CellRendererText();
    type_cell.xalign = 1;
    _search_list.insert_column_with_attributes( -1, null, type_cell,              "markup", 0, null );
    _search_list.insert_column_with_attributes( -1, null, new CellRendererText(), "markup", 1, null );
    _search_list.headers_visible = false;
    _search_list.activate_on_single_click = true;
    _search_list.enable_search = false;
    _search_list.row_activated.connect( on_search_clicked );

    /* Create the scrolled window for the treeview */
    _search_scroll = new ScrolledWindow( null, null );
    _search_scroll.height_request = 200;
    _search_scroll.hscrollbar_policy = PolicyType.EXTERNAL;
    _search_scroll.add( _search_list );

    var search_opts = new Expander( _( "Search Criteria" ) );
    search_opts.add( create_search_options_box() );

    box.margin = 5;
    box.pack_start( _search_entry,  false, true );
    box.pack_start( _search_scroll, true,  true );
    box.pack_start( new Separator( Orientation.HORIZONTAL ) );
    box.pack_start( search_opts,    false, true, 5 );
    box.show_all();

    /* Create the popover and associate it with the menu button */
    _search = new Popover( null );
    _search.add( box );
    _search_btn.popover = _search;

  }

  /* Creates the UI for the search criteria box */
  private Grid create_search_options_box() {

    var grid = new Grid();

    _search_titles   = new CheckButton.with_label( _( "Titles" ) );
    _search_notes    = new CheckButton.with_label( _( "Notes" ) );
    _search_folded   = new CheckButton.with_label( _( "Folded" ) );
    _search_unfolded = new CheckButton.with_label( _( "Unfolded" ) );
    _search_tasks    = new CheckButton.with_label( _( "Tasks" ) );
    _search_nontasks = new CheckButton.with_label( _( "Non-tasks" ) );

    /* Set the active values from the settings */
    _search_titles.active   = _settings.get_boolean( "search-opt-titles" );
    _search_notes.active    = _settings.get_boolean( "search-opt-notes" );
    _search_folded.active   = _settings.get_boolean( "search-opt-folded" );
    _search_unfolded.active = _settings.get_boolean( "search-opt-unfolded" );
    _search_tasks.active    = _settings.get_boolean( "search-opt-tasks" );
    _search_nontasks.active = _settings.get_boolean( "search-opt-nontasks" );

    /* Set the checkbutton sensitivity */
    _search_titles.set_sensitive( _search_notes.active );
    _search_notes.set_sensitive( _search_titles.active );
    _search_folded.set_sensitive( _search_unfolded.active );
    _search_unfolded.set_sensitive( _search_folded.active );
    _search_tasks.set_sensitive( _search_nontasks.active );
    _search_nontasks.set_sensitive( _search_tasks.active );

    _search_titles.toggled.connect(() => {
      _settings.set_boolean( "search-opt-titles", _search_titles.active );
      _search_notes.set_sensitive( _search_titles.active );
      on_search_change();
    });
    _search_notes.toggled.connect(() => {
      _settings.set_boolean( "search-opt-notes", _search_notes.active );
      _search_titles.set_sensitive( _search_notes.active );
      on_search_change();
    });
    _search_folded.toggled.connect(() => {
      _settings.set_boolean( "search-opt-folded", _search_folded.active );
      _search_unfolded.set_sensitive( _search_folded.active );
      on_search_change();
    });
    _search_unfolded.toggled.connect(() => {
      _settings.set_boolean( "search-opt-unfolded", _search_unfolded.active );
      _search_folded.set_sensitive( _search_unfolded.active );
      on_search_change();
    });
    _search_tasks.toggled.connect(() => {
      _settings.set_boolean( "search-opt-tasks", _search_tasks.active );
      _search_nontasks.set_sensitive( _search_tasks.active );
      on_search_change();
    });
    _search_nontasks.clicked.connect(() => {
      _settings.set_boolean( "search-opt-nontasks", _search_nontasks.active );
      _search_tasks.set_sensitive( _search_nontasks.active );
      on_search_change();
    });

    grid.margin_top         = 10;
    grid.column_homogeneous = true;
    grid.attach( _search_titles,   0, 0, 1, 1 );
    grid.attach( _search_notes,    0, 1, 1, 1 );
    grid.attach( _search_folded,   1, 0, 1, 1 );
    grid.attach( _search_unfolded, 1, 1, 1, 1 );
    grid.attach( _search_tasks,    2, 0, 1, 1 );
    grid.attach( _search_nontasks, 2, 1, 1, 1 );

    return( grid );

  }

  /* Adds the export functionality */
  private void add_export_button() {

    /* Create the menu button */
    var menu_btn = new MenuButton();
    menu_btn.set_image( new Image.from_icon_name( "document-export", IconSize.LARGE_TOOLBAR ) );
    menu_btn.set_tooltip_text( _( "Export" ) );
    _header.pack_end( menu_btn );

    /* Create export menu */
    var box = new Box( Orientation.VERTICAL, 5 );

    var export = new ModelButton();
    export.text = _( "Export..." );
    export.action_name = "win.action_export";

    var print = new ModelButton();
    print.text = _( "Print" );
    print.action_name = "win.action_print";
    print.set_sensitive( false );

    box.margin = 5;
    box.pack_start( export, false, true );
    box.pack_start( new Separator( Orientation.HORIZONTAL ), false, true );
    box.pack_start( print,  false, true );
    box.show_all();

    /* Create the popover and associate it with clicking on the menu button */
    _export = new Popover( null );
    _export.add( box );
    menu_btn.popover = _export;

  }

  /* Adds the property functionality */
  private void add_property_button() {

    /* Add the menubutton */
    _prop_show = new Image.from_icon_name( "pane-show-symbolic", IconSize.LARGE_TOOLBAR );
    _prop_hide = new Image.from_icon_name( "pane-hide-symbolic", IconSize.LARGE_TOOLBAR );
    _prop_btn  = new Button();
    _prop_btn.image = _prop_show;
    _prop_btn.set_tooltip_text( _( "Properties" ) );
    _prop_btn.clicked.connect( inspector_clicked );
    _header.pack_end( _prop_btn );

/* TBD - Sidebar created here
    var box = new Box( Orientation.VERTICAL, 20 );
    var sb  = new StackSwitcher();

    // TBD - _node_inspector = new NodeInspector( _table );

    _stack = new Stack();
    _stack.set_transition_type( StackTransitionType.SLIDE_LEFT_RIGHT );
    _stack.set_transition_duration( 500 );
    _stack.add_titled( _node_inspector, "node", _("Node") );
    _stack.add_titled( new MapInspector( _table, _settings ),  "map",  _("Map") );

    _stack.notify.connect((ps) => {
      if( ps.name == "visible-child" ) {
        _settings.set_boolean( "node-properties-shown", (_stack.visible_child_name == "node") );
        _settings.set_boolean( "map-properties-shown",  (_stack.visible_child_name == "map") );
      }
    });

    sb.homogeneous = true;
    sb.set_stack( _stack );

    box.margin = 5;
    box.pack_start( sb,     false, true, 0 );
    box.pack_start( _stack, true,  true, 0 );
    box.show_all();

    _inspector = new Revealer();
    _inspector.set_transition_type( RevealerTransitionType.SLIDE_LEFT );
    _inspector.set_transition_duration( 500 );
    _inspector.child = box;

    if( _settings.get_boolean( "node-properties-shown" ) ) {
      show_properties( "node", false );
    } else if( _settings.get_boolean( "map-properties-shown" ) ) {
      show_properties( "map", false );
    }
*/

  }

  /* Show or hides the inspector sidebar */
  private void inspector_clicked() {
/*
    if( _inspector.child_revealed ) {
      hide_properties();
    } else {
      show_properties( null, false );
    }
*/
  }

  /* Displays the save warning dialog window */
  public bool show_save_warning( OutlineTable ot ) {

    var dialog = new Granite.MessageDialog.with_image_from_icon_name(
      _( "Save current unnamed document?" ),
      _( "Changes will be permanently lost if not saved." ),
      "dialog-warning",
      ButtonsType.NONE
    );

    var dont = new Button.with_label( _( "Discard Changes" ) );
    dialog.add_action_widget( dont, ResponseType.CLOSE );

    var cancel = new Button.with_label( _( "Cancel" ) );
    dialog.add_action_widget( cancel, ResponseType.CANCEL );

    var save = new Button.with_label( _( "Save" ) );
    save.get_style_context().add_class( STYLE_CLASS_SUGGESTED_ACTION );
    dialog.add_action_widget( save, ResponseType.ACCEPT );

    dialog.set_transient_for( this );
    dialog.set_default_response( ResponseType.ACCEPT );
    dialog.set_title( "" );

    dialog.show_all();

    var res = dialog.run();

    dialog.destroy();

    switch( res ) {
      case ResponseType.ACCEPT :  save_file( ot );       break;
      case ResponseType.CLOSE  :  ot.document.remove();  break;
    }

    return( false );

  }

  /* Creates a new document and adds it to the notebook */
  public void do_new_file() {

    var ot = add_tab( null, TabAddReason.NEW );

    /* Set the title to indicate that we have a new document */
    update_title( ot );

  }

  /* Allow the user to open a Outliner file */
  public void do_open_file() {

    /* Get the file to open from the user */
    FileChooserNative dialog = new FileChooserNative( _( "Open File" ), this, FileChooserAction.OPEN, _( "Open" ), _( "Cancel" ) );

    /* Create file filters */
    var filter = new FileFilter();
    filter.set_filter_name( "Outliner" );
    filter.add_pattern( "*.outliner" );
    dialog.add_filter( filter );

    filter = new FileFilter();
    filter.set_filter_name( "Freemind / Freeplane" );
    filter.add_pattern( "*.mm" );
    dialog.add_filter( filter );

    filter = new FileFilter();
    filter.set_filter_name( "Minder" );
    filter.add_pattern( "*.minder" );
    dialog.add_filter( filter );

    filter = new FileFilter();
    filter.set_filter_name( "OPML" );
    filter.add_pattern( "*.opml" );
    dialog.add_filter( filter );

    if( dialog.run() == ResponseType.ACCEPT ) {
      open_file( dialog.get_filename() );
    }

    get_current_table( "do_open_file" ).grab_focus();

  }

  /* Opens the file and display it in the table */
  public bool open_file( string fname ) {
    if( !FileUtils.test( fname, FileTest.IS_REGULAR ) ) {
      return( false );
    }
/* TBD
    if( fname.has_suffix( ".outliner" ) ) {
      _doc = new Document( _table, _settings );
      _table.initialize_for_open();
      _doc.filename = fname;
      update_title();
      _doc.load();
      return( true );
    } else if( fname.has_suffix( ".opml" ) ) {
      _doc = new Document( _table, _settings );
      _table.initialize_for_open();
      update_title();
      ExportOPML.import( fname, _table );
      return( true );
    } else if( fname.has_suffix( ".minder" ) ) {
      _doc = new Docuemnt( _table, _settings );
      _table.initialize_for_open();
      update_title();
      ExportMinder.import( fname, _table );
      return( true );
    }
*/
    return( false );
  }

  /* Perform an undo action */
  public void do_undo() {
    var table = get_current_table( "do_undo" );
    table.undo_buffer.undo();
    table.grab_focus();
  }

  /* Perform a redo action */
  public void do_redo() {
    var table = get_current_table( "do_redo" );
    table.undo_buffer.redo();
    table.grab_focus();
  }

  /* Performs an indent operation on the currently selected row */
  public void do_indent() {
    get_current_table( "do_indent" ).indent();
  }

  /* Performs an unindent operation on the currently selected row */
  public void do_unindent() {
    get_current_table( "do_unindent" ).unindent();
  }

  private bool on_table_mapped( Gdk.EventAny e ) {
    get_current_table().queue_draw();
    return( false );
  }

  /* Called whenever the theme is changed */
  private void on_theme_changed( OutlineTable ot ) {
    Gtk.Settings? settings = Gtk.Settings.get_default();
    if( settings != null ) {
      settings.gtk_application_prefer_dark_theme = ot.get_theme().prefer_dark;
    }
  }

  /*
   Called whenever the undo buffer changes state.  Updates the state of
   the undo and redo buffer buttons.
  */
  public void do_buffer_changed( OutlineTable ot ) {
    _undo_btn.set_sensitive( ot.undo_buffer.undoable() );
    _undo_btn.set_tooltip_text( ot.undo_buffer.undo_tooltip() );
    _redo_btn.set_sensitive( ot.undo_buffer.redoable() );
    _redo_btn.set_tooltip_text( ot.undo_buffer.redo_tooltip() );
  }

  /* Allow the user to select a filename to save the document as */
  public bool save_file( OutlineTable ot ) {
    FileChooserDialog dialog = new FileChooserDialog( _( "Save File" ), this, FileChooserAction.SAVE,
      _( "Cancel" ), ResponseType.CANCEL, _( "Save" ), ResponseType.ACCEPT );
    FileFilter        filter = new FileFilter();
    bool              retval = false;
    filter.set_filter_name( _( "Outliner" ) );
    filter.add_pattern( "*.outliner" );
    dialog.add_filter( filter );
    if( dialog.run() == ResponseType.ACCEPT ) {
      string fname = dialog.get_filename();
      if( fname.substring( -7, -1 ) != ".outliner" ) {
        fname += ".outliner";
      }
      _doc.filename = fname;
      _doc.save();
      update_title( ot );
      retval = true;
    }
    dialog.close();
    ot.grab_focus();
    return( retval );
  }

  /* Called when the save as button is clicked */
  public void do_save_as_file() {
    save_file( get_current_table( "do_save_as_file" ) );
  }

  /* Called whenever the row selection changes in the table */
  private void on_row_changed() {
  }

  /* Displays the node properties panel for the current node */
  private void show_properties( string? tab, bool grab_note ) {
    if( _inspector.reveal_child && ((tab == null) || (_stack.visible_child_name == tab)) ) return;
    _prop_btn.image = _prop_hide;
    if( tab != null ) {
      _stack.visible_child_name = tab;
    }
    if( !_inspector.reveal_child ) {
      _inspector.reveal_child = true;
    }
    _settings.set_boolean( (_stack.visible_child_name + "-properties-shown"), true );
/*
    if( _stack.visible_child_name == "node" ) {
      if( grab_note ) {
        _node_inspector.grab_note();
      } else {
        _node_inspector.grab_name();
      }
    }
*/
  }

  /* Hides the node properties panel */
  private void hide_properties() {
    if( !_inspector.reveal_child ) return;
    _prop_btn.image = _prop_show;
    _inspector.reveal_child = false;
    _settings.set_boolean( "node-properties-shown", false );
    _settings.set_boolean( "map-properties-shown",  false );
  }

  /* Called when the user uses the Control-n keyboard shortcut */
  private void action_new() {
    do_new_file();
  }

  /* Called when the user uses the Control-o keyboard shortcut */
  private void action_open() {
    do_open_file();
  }

  /* Called when the user uses the Control-s keyboard shortcut */
  private void action_save() {
    var table = get_current_table( "action_save" );
    if( table.document.is_saved() ) {
      table.document.save();
    } else {
      save_file( table );
    }
  }

  /* Called when the user uses the Control-S keyboard shortcut */
  private void action_save_as() {
    do_save_as_file();
  }

  /* Called when the user uses the Control-z keyboard shortcut */
  private void action_undo() {
    do_undo();
  }

  /* Called when the user uses the Control-Z keyboard shortcut */
  private void action_redo() {
    do_redo();
  }

  /* Called when the user uses the Control-f keyboard shortcut */
  private void action_search() {
    _search_btn.clicked();
  }

  /* Called when the user uses the Control-q keyboard shortcut */
  private void action_quit() {
    destroy();
  }

  /* Display matched items to the search within the search popover */
  private void on_search_change() {
    bool[] search_opts = {
      _search_titles.active,    // 0
      _search_notes.active,     // 1
      _search_folded.active,    // 2
      _search_unfolded.active,  // 3
      _search_tasks.active,     // 4
      _search_nontasks.active   // 5
    };
    _search_items.clear();
    if( _search_entry.get_text() != "" ) {
      get_current_table( "on_search_change" ).get_match_items(
        _search_entry.get_text().casefold(),
        search_opts,
        ref _search_items
      );
    }
  }

  /*
   Called when the user selects an item in the search list.  The current node
   will be set to the node associated with the selection.
  */
  private void on_search_clicked( TreePath path, TreeViewColumn col ) {
    TreeIter it;
    Node?    node = null;
    _search_items.get_iter( out it, path );
    _search_items.get( it, 2, &node, -1 );
    if( node != null ) {
/*
      _canvas.set_current_node( node );
      _canvas.see();
*/
    }
    _search.closed();
    get_current_table( "on_search_clicked" ).grab_focus();
  }

  /* Exports the model to various formats */
  private void action_export() {

    FileChooserDialog dialog = new FileChooserDialog( _( "Export As" ), this, FileChooserAction.SAVE,
      _( "Cancel" ), ResponseType.CANCEL, _( "Export" ), ResponseType.ACCEPT );

    /* CSV */
    FileFilter csv_filter = new FileFilter();
    csv_filter.set_filter_name( _( "CSV" ) );
    csv_filter.add_pattern( "*.csv" );
    dialog.add_filter( csv_filter );

    /* Markdown */
    FileFilter md_filter = new FileFilter();
    md_filter.set_filter_name( _( "Markdown" ) );
    md_filter.add_pattern( "*.md" );
    md_filter.add_pattern( "*.markdown" );
    dialog.add_filter( md_filter );

    /* Minder */
    FileFilter minder_filter = new FileFilter();
    minder_filter.set_filter_name( _( "Minder" ) );
    minder_filter.add_pattern( "*.minder" );
    dialog.add_filter( minder_filter );

    /* OPML */
    FileFilter opml_filter = new FileFilter();
    opml_filter.set_filter_name( _( "OPML" ) );
    opml_filter.add_pattern( "*.opml" );
    dialog.add_filter( opml_filter );

    /* PDF */
    FileFilter pdf_filter = new FileFilter();
    pdf_filter.set_filter_name( _( "PDF" ) );
    pdf_filter.add_pattern( "*.pdf" );
    dialog.add_filter( pdf_filter );

    /* PlainText */
    FileFilter txt_filter = new FileFilter();
    txt_filter.set_filter_name( _( "PlainText" ) );
    txt_filter.add_pattern( "*.txt" );
    dialog.add_filter( txt_filter );

    if( dialog.run() == ResponseType.ACCEPT ) {

      var fname  = dialog.get_filename();
      var filter = dialog.get_filter();
      var table  = get_current_table( "action_export" );

/* TBD
      if( csv_filter == filter ) {
        ExportCSV.export( repair_filename( fname, {".csv"} ), table );
      } else if( md_filter == filter ) {
        ExportMarkdown.export( repair_filename( fname, {".md", ".markdown"} ), table );
      } else if( minder_filter == filter ) {
        ExportMinder.export( repair_filename( fname, {".minder"} ), table );
      } else if( opml_filter == filter ) {
        ExportOPML.export( repair_filename( fname, {".opml"} ), table );
      } else if( pdf_filter == filter ) {
        ExportPDF.export( repair_filename( fname, {".pdf"} ), table );
      } else if( txt_filter == filter ) {
        ExportText.export( repair_filename( fname, {".txt"} ), table );
      } else if( 
*/
    }

    dialog.close();

  }

  /*
   Checks the given filename to see if it contains any of the given suffixes.
   If a valid suffix is found, return the filename without modification; otherwise,
   returns the filename with the extension added.
  */
  private string repair_filename( string fname, string[] extensions ) {
    foreach (string ext in extensions) {
      if( fname.has_suffix( ext ) ) {
        return( fname );
      }
    }
    return( fname + extensions[0] );
  }

  /* Exports the model to the printer */
  private void action_print() {
/* TBD
    var print = new ExportPrint();
    print.print( _canvas, this );
*/
  }

}

