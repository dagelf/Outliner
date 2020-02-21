/*
* Copyright (c) 2020 (https://github.com/phase1geo/Outliner)
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

public class ExportPrint : Object {

  struct PageBoundary {
    public Node   node;
    public double include_size;
  }

  private OutlineTable         _table;
  private PrintOperation       _op;
  private Array<PageBoundary?> _boundaries;

  /* Default constructor */
  public ExportPrint() {}

  /* Perform print operation */
  public void print( OutlineTable table, MainWindow main ) {

    _table      = table;
    _op         = new PrintOperation();
    _boundaries = new Array<PageBoundary?>();
    // _boundaries.append_val( { table.root.get_next_node(), 0 } );

    var settings = new PrintSettings();

    _op.set_print_settings( settings );
    // _op.set_unit( Unit.POINTS );
    _op.set_unit( Unit.NONE );

    /* Connect to the draw_page signal */
    _op.begin_print.connect( begin_print );
    _op.draw_page.connect( draw_page );

    try {
      var res = _op.run( PrintOperationAction.PRINT_DIALOG, main );
      switch( res ) {
        case PrintOperationResult.APPLY :
          settings = _op.get_print_settings();
          // Save the settings to a file - settings.to_file( fname );
          break;
        case PrintOperationResult.ERROR :
          /* TBD - Display the print error */
          break;
        case PrintOperationResult.IN_PROGRESS :
          /* TBD */
          break;
      }
    } catch( GLib.Error e ) {
      /* TBD */
    }

  }

  /* Calculates the page breaks in the document */
  public void begin_print( PrintContext context ) {

    var include_size = 1.0;
    var sf           = ((7.5 / 8.5) * context.get_width()) / _table.get_allocated_width();
    var page_size    = (int)(((10.0 / 11.0) * context.get_height()) / sf);
    var node         = _table.root.get_next_node();

    while( node != null ) {
      if( node.on_page_boundary( page_size, out include_size ) ) {
        _boundaries.append_val( { node, include_size } );
      }
      node = node.get_next_node();
    }

    _op.set_n_pages( (int)_boundaries.length );

  }

  /* Draws the page */
  public void draw_page( PrintOperation op, PrintContext context, int page_nr ) {

    var alloc_width  = _table.get_allocated_width();
    var ctx          = context.get_cairo_context();
    var sf           = ((7.5 / 8.5) * context.get_width()) / alloc_width;
    var margin       = (0.5 / 8.5) * context.get_width();
    var theme        = MainWindow.themes.get_theme( "default" );
    var start        = _boundaries.index( page_nr );
    var node         = start.node;
    var end_node     = (_boundaries.length == (page_nr + 1)) ? null : _boundaries.index( page_nr + 1 ).node;

    /* Clip the area */
    ctx.rectangle( margin, margin, (context.get_width() - margin), (context.get_height() - margin) );
    ctx.clip();

    /* Scale and translate the image */
    ctx.translate( margin, (0 - ((node.y - start.include_size) * sf)) + margin );
    ctx.scale( sf, sf );

    stdout.printf( "node.y: %g, translated: %g\n", (node.y * sf), (0 - ((node.y - start.include_size) * sf)) );

    /* Draw the nodes, starting with the start node */
    while( true ) {
      node.draw_background( ctx, theme );
      node.draw_expander( ctx, theme );
      node.draw_name( ctx, theme );
      node.draw_note( ctx, theme );
      if( node == end_node ) {
        break;
      }
      node = node.get_next_node();
    }

  }

}
