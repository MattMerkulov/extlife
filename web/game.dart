import 'dart:html';
import 'dart:math';
import 'dart:async';

class Main {
	static int cellXQuantity, cellYQuantity, cellSize;
	static final CanvasElement canvas = new CanvasElement();
	static TableCellElement cell;
	static final SelectElement fieldSizeCombobox = new SelectElement();
	static final SelectElement initialConfCombobox = new SelectElement();
	static final SelectElement fpsCombobox = new SelectElement();
	static final ButtonElement pauseButton = new ButtonElement();
	static Timer timer;

	static final Map<String, int> fieldSizeMap = { "256x256 field" : 256, "128x128 field" : 128,  "64x64 field" : 64, "512x512 field" : 512 };

	static String get configurationName => initialConfCombobox.options[ initialConfCombobox.selectedIndex ].label;

	static final Map<String, int> fpsMap = { "Max FPS" : 1, "200 FPS" : 5, "25 FPS" : 40, "5 FPS" : 200 };

	static int get time => fpsMap[ fpsCombobox.options[ fpsCombobox.selectedIndex ].label ];

	static bool get paused => pauseButton.text == "Resume";

	static int mouseCellX( MouseEvent event ) => event.offset.x ~/ cellSize;
	static int mouseCellY( MouseEvent event ) => event.offset.y ~/ cellSize;


	static int oldMouseX, oldMouseY;
	static bool paint = false, mode;

	static void init() {
		canvas.onMouseMove.listen( (event) {
			int x = mouseCellX( event );
			int y = mouseCellY( event );
			if( paint && paused && ( x != oldMouseX || y != oldMouseY ) ) {
				Cell.set( mouseCellX( event ), mouseCellY( event ), mode );
				oldMouseX = x;
				oldMouseY = y;
				draw();
			}
		} );
		canvas.onMouseDown.listen( (event) {
			paint = true;
			mode = !Cell.getState( mouseCellX( event ), mouseCellY( event ) );
			oldMouseX = 0;
			oldMouseY = 0;
		} );
		canvas.onMouseUp.listen( (event) {
			paint = false;
		} );


		fieldSizeCombobox.onChange.listen( (event) {
			fieldInit( fieldSizeMap[ fieldSizeCombobox.options[ fieldSizeCombobox.selectedIndex ].label ] );
		} );

		initialConfCombobox.onChange.listen( (event) {
			Cell.createConfiguration();
		} );

		fpsCombobox.onChange.listen( (event) {
			timerInit();
		});

		pauseButton
			..text = "Pause"
			..onClick.listen( (event) {
				pauseButton.text = ( paused ? "Pause" : "Resume" );
			} );


		TableElement table = new TableElement();
		TableRowElement row = table.insertRow( 0 );
		cell = row.insertCell( 0 )
			..setAttribute( "align", "center" );
		TableCellElement cell2 = table.insertRow( 1 ).insertCell( 0 )
			..setAttribute( "align", "center" );

		for( String caption in Rules.sets.keys ) {
			ButtonElement button = new ButtonElement()
				..text = caption
				..onClick.listen( (event) {
					Group.groups.clear();
					Group.cellStateRule = null;
					Rules.sets[ caption ]();
					Cell.createConfiguration();
				} );
			cell.append( button );
		}

		Map<SelectElement, Map<String, Object>> comboboxMap =
			{ fieldSizeCombobox : fieldSizeMap, initialConfCombobox : Cell.configurations, fpsCombobox : fpsMap };
		for( SelectElement combobox in comboboxMap.keys ) {
			for( String name in comboboxMap[ combobox ].keys ) {
				combobox.append( new OptionElement( data:name ) );
			}
			cell2.append( combobox );
		}

		cell2.append( pauseButton );

		document.body
			..append( table )
			..append( canvas );

		fieldInit( 256 );
		timerInit();
	}


	static void fieldInit( int cellQuantity ) {
		cellXQuantity = cellQuantity;
		cellYQuantity = cellQuantity;
		cellSize = 800 ~/ cellQuantity;

		Cell.cellXMask = cellXQuantity - 1;
		Cell.cellYMask = cellYQuantity - 1;
		Cell.xCenter = cellXQuantity ~/ 2;
		Cell.yCenter = cellYQuantity ~/ 2;

		canvas
			..width = cellSize * cellXQuantity + 1
			..height = cellSize * cellYQuantity + 1;

		cell.setAttribute( "width", Main.canvas.width.toString() );

		Cell.createConfiguration();
	}

	static void timerInit() {
		if( timer != null ) timer.cancel();
		timer = new Timer.periodic( new Duration( milliseconds:time ), Cell.gen );
	}

	static void draw( [ bool clear = true ] ) {
		CanvasRenderingContext2D context = canvas.context2D;
		if( clear ) {
			context
				..fillStyle = '#444'
				..fillRect( 0, 0, canvas.width, canvas.height );
		}
		List<Cell> list = clear ? Cell.cells : Cell.togglingCells;
		int size = cellSize > 1 ? cellSize - 1 :cellSize;
		for( Cell cell in list ) {
			context
				..fillStyle = cell.state ? '#FFF' : '#444'
				..fillRect( ( cell.x & Cell.cellXMask ) * cellSize + 1, ( cell.y & Cell.cellYMask ) * cellSize + 1, size, size );
		}
	}
}


class Range {
	Group group;
	int from, to;

	Range( this.group, this.from, this.to );
}



class Group {
	static List<Group> groups = new List<Group>();

	List<List<int>> positions;
	int k = 1;


	Group( this.positions ){
		groups.add( this );
	}


	static List<bool> cellStateRule = null;

	static void init() {
		int k = 1;
		for( Group group in groups ) {
			group.k = k;
			k *= ( group.positions.length + 1 );
		}
		cellStateRule = new List<bool>( k );
		for( int n = 0; n < k; n++ ) cellStateRule[ n ] = false;
	}

	Range range( int from, [ int to ] ) => new Range( this, from, ( to == null ? from : to ) );
}



class Rules {
	static Group cell, neighbors, hor, center, vert, top, bottom, left, right, first, second, diagonal, horvert;

	static final Map<String, Function> sets = {
		"Classic Life" : (){
			groupCellNeighbors();
			set( [ cell.range( 1 ), neighbors.range( 2, 3 ) ] );
			set( [ cell.range( 0 ), neighbors.range( 3 ) ] );
		}, "SandyLifeHV" : (){
			groupCellDiagonalHorvert();
			set( [ cell.range( 0 ), diagonal.range( 2 ), horvert.range( 0, 1 ) ] );
			set( [ cell.range( 0 ), diagonal.range( 0 ), horvert.range( 2 ) ] );
			set( [ cell.range( 1 ), diagonal.range( 1, 2 ), horvert.range( 1, 2 ) ] );
		}, "SandyLifeD" : (){
			groupCellDiagonalHorvert();
			set( [ cell.range( 0 ), diagonal.range( 2 ), horvert.range( 0 ) ] );
			set( [ cell.range( 0 ), diagonal.range( 0, 1 ), horvert.range( 2 ) ] );
			set( [ cell.range( 1 ), diagonal.range( 1, 2 ), horvert.range( 1, 2 ) ] );
		}, "AmoebaLife" : (){
			groupCellDiagonalHorvert();
			set( [ cell.range( 0 ), diagonal.range( 2 ), horvert.range( 0, 2 ) ] );
			set( [ cell.range( 0 ), diagonal.range( 0, 2 ), horvert.range( 2 ) ] );
			set( [ cell.range( 1 ), diagonal.range( 2 ), horvert.range( 0, 2 ) ] );
		}, "ElectronicLife" : (){
			groupCellDiagonalHorvert();
			set( [ cell.range( 0 ), diagonal.range( 2, 3 ), horvert.range( 2 ) ] );
			set( [ cell.range( 0 ), diagonal.range( 0, 1 ), horvert.range( 2, 3 ) ] );
			set( [ cell.range( 1 ), diagonal.range( 1, 2 ), horvert.range( 1, 2 ) ] );
		}, "LiquidLife" : (){
			groupTopCenterBottom();
			set( [ top.range( 0, 1 ), center.range( 1, 3 ), bottom.range( 2, 3 ) ] );
			set( [ top.range( 1, 2 ), center.range( 2, 3 ), bottom.range( 0, 1 ) ] );
			set( [ top.range( 2, 3 ), center.range( 1, 3 ), bottom.range( 1, 2 ) ] );
		}, "ArmadaLife" : (){
			groupTopCenterBottom();
			set( [ top.range( 0, 1 ), center.range( 1, 2 ), bottom.range( 2, 3 ) ] );
			set( [ top.range( 1, 3 ), center.range( 1, 2 ), bottom.range( 1, 3 ) ] );
			set( [ top.range( 2, 3 ), center.range( 1, 2 ), bottom.range( 0, 1 ) ] );
		}, "WireLife" : () {
			groupHorCenterVert();
			set( [ hor.range( 2 ), center.range( 0 ), vert.range( 2, 3 ) ] );
			set( [ hor.range( 1, 3 ), center.range( 1 ), vert.range( 1, 2 ) ] );
		}, "TwirlLife" : () {
			groupHorCenterVert();
			set( [ hor.range( 2 ), center.range( 0 ), vert.range( 2 ) ] );
			set( [ hor.range( 1, 3 ), center.range( 1 ), vert.range( 1, 3 ) ] );
		}, "Fractal 1" : (){
			groupCellDiagonalHorvert();
			set( [ cell.range( 0 ), horvert.range( 1 ) ] );
			set( [ cell.range( 1 ) ] );
		}, "Fractal 2" : (){
			groupCellDiagonalHorvert();
			set( [ cell.range( 0 ), diagonal.range( 1 ) ] );
			set( [ cell.range( 1 ) ] );
		}, "Carpet" : (){
			groupCellDiagonalHorvert();
			set( [ cell.range( 0 ), diagonal.range( 1, 2 ), horvert.range( 0 ) ] );
			set( [ cell.range( 0 ), diagonal.range( 0 ), horvert.range( 1, 2 ) ] );
			set( [ cell.range( 1 ), diagonal.range( 0, 2 ), horvert.range( 0, 2 ) ] );
		}, "Snakes" : (){
			groupCellFirstSecond();
			set( [ cell.range( 0 ), first.range( 2, 3 ), second.range( 0 ) ] );
			set( [ cell.range( 0 ), first.range( 0 ), second.range( 2, 3 ) ] );
			set( [ cell.range( 1 ), first.range( 1, 2 ), second.range( 1, 2 ) ] );
		}, "Mice": () {
			groupTopCenterBottom();
			set( [ top.range( 0, 2 ), center.range( 1, 2 ), bottom.range( 2, 3 ) ] );
			set( [ top.range( 1, 2 ), center.range( 1 ), bottom.range( 0, 2 ) ] );
			set( [ top.range( 2, 3 ), center.range( 1, 2 ), bottom.range( 1, 2 ) ] );
		}, "Fiber" : (){
			groupTopCenterBottom();
			set( [ top.range( 0, 0 ), center.range( 1, 2 ), bottom.range( 2, 3 ) ] );
			set( [ top.range( 1, 2 ), center.range( 1, 3 ), bottom.range( 1, 2 ) ] );
			set( [ top.range( 2, 3 ), center.range( 1, 2 ), bottom.range( 0 ) ] );
		}, "Smoke" : () {
			groupTopLeftCenterBottomRight();
			set( [ center.range( 0 ), left.range( 3, 3 ), right.range( 1, 3 ) ] );
			set( [ center.range( 0 ), left.range( 1, 3 ), right.range( 3, 3 ) ] );
			set( [ center.range( 0 ), top.range( 3, 3 ), bottom.range( 0, 1 ) ] );
			set( [ center.range( 0 ), top.range( 0, 1 ), bottom.range( 3, 3 ) ] );
			set( [ center.range( 1 ), bottom.range( 1, 3 ), top.range( 1, 3 ) ] );
		}, "Fall" : () {
			groupTopLeftCenterBottomRight();
			int k1=2, k2=3, k3=1, k4=2;
			set( [ center.range( 0 ), left.range( k1, k2 ), right.range( k3, k4 ) ] );
			set( [ center.range( 0 ), left.range( k3, k4 ), right.range( k1, k2 ) ] );
			set( [ center.range( 0 ), top.range( k1, k2 ), bottom.range( k3, k4 ) ] );
			set( [ center.range( 0 ), top.range( k3, k4 ), bottom.range( k1, k2 ) ] );
			set( [ center.range( 1 ), bottom.range( 0, 1 ), top.range( 1, 3 ) ] );
		}, "Freezer" : () {
			groupTopLeftCenterBottomRight();
			set( [ center.range( 0 ), left.range( 1, 2 ), bottom.range( 2, 2 ) ] );
			set( [ center.range( 0 ), top.range( 2, 2 ), right.range( 1, 2 ) ] );
			set( [ center.range( 1 ), bottom.range( 1, 3 ), left.range( 0, 2 ) ] );
			set( [ center.range( 1 ), top.range( 0, 2 ), right.range( 1, 3 ) ] );
		}
	};


	static void groupCellNeighbors() {
		cell = new Group( [ [ 0, 0 ] ] );
		neighbors = new Group( [ [ -1, -1 ], [ 1, -1 ], [ 1, 1 ], [ -1, 1 ], [ 0, -1 ], [ -1, 0 ], [ 1, 0 ], [ 0, 1 ] ] );
	}

	static void groupCellFirstSecond() {
		cell = new Group( [ [ 0, 0 ] ] );
		first = new Group( [ [ -1, 0 ], [ -1, -1 ], [ 0, -1 ], [ 1, -1 ] ] );
		second = new Group( [ [ -1, 1 ], [ 0, 1 ], [ 1, 1 ], [ 1, 0 ] ] );
	}

	static void groupHorCenterVert() {
		hor = new Group( [ [ -1, -1 ], [ 0, -1 ], [ 1, -1 ], [ -1, 1 ], [ 0, 1 ], [ 1, 1 ] ] );
		center = new Group( [ [ 0, 0 ] ] );
		vert = new Group( [ [ -1, -1 ], [ -1, 0 ], [ -1, 1 ], [ 1, -1 ], [ 1, 0 ], [ 1, 1 ] ] );
	}

	static void groupTopCenterBottom() {
		top = new Group( [ [ -1, -1 ], [ 0, -1 ], [ 1, -1 ] ] );
		center = new Group( [ [ -1, 0 ], [ 0, 0 ], [ 1, 0 ] ] );
		bottom = new Group( [ [ -1, 1 ], [ 0, 1 ], [ 1, 1 ] ] );
	}

	static void groupTopLeftCenterBottomRight() {
		top = new Group( [ [ -1, -1 ], [ 0, -1 ], [ 1, -1 ] ] );
		left = new Group( [ [ -1, -1 ], [ -1, 0 ], [ -1, 1 ] ] );
		center = new Group( [ [ 0, 0 ] ] );
		bottom = new Group( [ [ -1, 1 ], [ 0, 1 ], [ 1, 1 ] ] );
		right = new Group( [ [ 1, -1 ], [ 1, 0 ], [ 1, 1 ] ] );
	}

	static void groupCellDiagonalHorvert() {
		cell = new Group( [ [ 0, 0 ] ] );
		diagonal = new Group( [ [ -1, -1 ], [ 1, -1 ], [ 1, 1 ], [ -1, 1 ] ] );
		horvert = new Group( [ [ 0, -1 ], [ -1, 0 ], [ 1, 0 ], [ 0, 1 ] ] );
	}


	static void set( List<Range> ranges, [bool cellState = true, int groupIndex = 0, int arrayIndex = 0 ] ) {
		if( Group.cellStateRule == null ) Group.init();
		Group group = Group.groups[ groupIndex ];
		Range range = ranges.firstWhere( (range) => range.group == group, orElse: () => null );
		for( int n = ( range == null ? 0 : range.from ); n <= ( range == null ? group.positions.length : range.to ); n++ ) {
			int index = arrayIndex + group.k * n;
			if( group == Group.groups.last ) {
				Group.cellStateRule[ index ] = cellState;
			} else {
				set( ranges, cellState, groupIndex + 1, index );
			}
		}
	}
}



class Cell {
	static List<Cell> cells = new List<Cell>();
	static List<Cell> cellSpace;

	static int cellXMask, cellYMask, xCenter, yCenter;

	static int cellAddress( x, y ) => ( x & cellXMask ) + Main.cellXQuantity * ( y & cellYMask );

	static bool getState( x, y ) {
		Cell cell = cellSpace[ cellAddress( x, y ) ];
		return ( cell == null ? false : cell.state );
	}

	static void createCell( x, y ) => Cell.toggle( xCenter + x, yCenter + y );

	int x, y, ruleIndex = 0;
	bool state, active = true;

	Cell( this.x, this.y, this.state );


	static Cell get( x, y ) {
		int address = cellAddress( x, y );
		Cell cell = cellSpace[ address ];
		if( cell == null ) {
			cell = new Cell( x, y, false );
			cellSpace[ address ] = cell;
			cells.add( cell );
		}
		return cell;
	}

	static int cellsQuantity;

	static void set( x, y, bool state, [ bool toggle = false ] ) {
		Cell cell = get( x, y );
		if( toggle ) state = !cell.state;
		if( state == cell.state ) return;
		cellsQuantity += state ? 1 : -1;
		int k = ( state ? 1 : -1 );
		for( Group group in Group.groups ) {
			for( List<int> coords in group.positions ) {
				Cell cell = get( x - coords[ 0 ], y - coords[ 1 ] );
				cell.ruleIndex += k * group.k;
				if( !cell.active ) {
					cells.add( cell );
					cell.active = true;
				}
			}
		}
		cell.state = state;
	}

	static void toggle( x, y ) => set( x, y, false, true );


	static int genNum = 0;

	static final List<Cell> togglingCells = new List<Cell>();

	static DateTime lastFPStime = new DateTime.now();
	static int fps = 0, fpsCounter = 0;

	static void gen( Timer timer ) {
		if( Main.paused || cells.isEmpty ) return;

		for( Cell cell in cells ) {
			if( Group.cellStateRule[ cell.ruleIndex ] != cell.state ) togglingCells.add( cell );
			cell.active = false;
		}

		cells.clear();

		for( Cell cell in togglingCells ) toggle( cell.x, cell.y );

		genNum++;
		document.title = "$cellsQuantity / $genNum / $fps";
		Main.draw( false );

		togglingCells.clear();

		DateTime now = new DateTime.now();
		if( now.isAfter( lastFPStime ) ) {
			lastFPStime = now.add( new Duration( seconds: 1 ) );
			fps = fpsCounter;
			fpsCounter = 0;
		} else {
			fpsCounter++;
		}
	}


	static final Map<String, Function> configurations = {
		"Random area 1/4" : (){ createArea( Main.cellXQuantity ~/ 2 ); },
		"Random area 1/16" : (){ createArea( Main.cellXQuantity ~/ 4 ); },
		"Random area 1/64" : (){ createArea( Main.cellXQuantity ~/ 8 ); },
		"Random area 1" : (){ createArea( Main.cellXQuantity ); },
		"Pentamino" : (){ createPolyomino( 5 ); },
		"Hexamino" : (){ createPolyomino( 6 ); },
		"Heptamino" : (){ createPolyomino( 7 ); },
		"Single cell" : (){ createCell( 0, 0 ); }
	};

	static void createConfiguration() {
		if( Group.groups.isEmpty ) return;

		genNum = 0;
		cellsQuantity = 0;

		cells.clear();
		cellSpace = new List<Cell>( Main.cellXQuantity * Main.cellYQuantity );
		configurations[ Main.configurationName ]();
		Main.draw();
	}

	static void createArea( int size ) {
		Random random = new Random();
		size = ( size - 1 ) ~/ 2;
		for( int y = -size - 1; y <= size; y++ ) {
			for( int x = -size - 1; x <= size; x++ ) {
				if( random.nextInt( 2 ) == 1 ) createCell( x, y );
			}
		}
	}

	static void createPolyomino( int cellsQuantity ) {
		createCell( 0, 0 );
		Random random = new Random();
		for( int n = 1; n < cellsQuantity; n++ ) {
			int x, y;
			while( true ) {
				Cell cell = cells[ random.nextInt( cells.length ) ];
				if( !cell.state ) continue;
				int posIndex = random.nextInt( 4 );
				x = cell.x + [ 0, -1, 1, 0 ][ posIndex ];
				y = cell.y + [ -1, 0, 0, 1 ][ posIndex ];
				if( !get( x, y ).state ) break;
			};
			toggle( x, y );
		}
	}
}


void main() {
	Main.init();
}