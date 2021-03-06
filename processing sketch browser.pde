
/*
An interactive Processing sketch code browser.
by Tim Fulton


With almost 700 sketches in my sketchbook, nearly 800 more
in 49 installed libraries, and another 1600+ in the included
examples, I have over 300K lines of Processing code on my machine.

When programming, I constantly want to refer to this codebase.  
Often its code I've written myself - something I've implemented
before and dont want to re-create.  Or maybe I want to quickly
look through the included examples - Schiffman is brilliant. 
And many times I want to read others' code - perhaps understanding
how to use a library.  

My needs quickly outgrew the capabilities of the IDE.  

I wanted something that would let me:

* view hundreds of sketchnames at a time without scrolling.
* hover on a sketchname to instantly preview its first page of code. 
* view my sketchbook in alphabetical order or by last modified time.
* explore a sketch's full code listing (all tabs) without opening it.
* navigate by hovering over controls, not clicking.
* open a sketch in a native IDE window with a mouse click.
* search all my sketches for a particular term.

So I wrote this interactive sketch code browser for lightning-fast exploration
of the sketchbook, the libraries, and the examples included in a Processing install. 

For me this is now an indispensable development tool, and I offer it, with my
thanks, to the Processing community.  

I'd welcome any comments or suggestions or questions or beer.  

Please let me know what you think!
 
============================================ 
1. Getting Started:

a. Install the apache.commons.io libraries - commons.apache.org/proper/commons-io/ 
b. Change the three File pathnames for your environment. I have a Mac.
c. Run the sketch.  Your sketchbook's contents should now be visible.

============================================
1. Basic Usage:

The browser starts in unclamped mode. Just point at a sketchname to preview
the first page of its code. In unclamped mode the sketchname is green and
you can scroll horizontally through the names by moving the mouse over the controls.
Preview any sketch without opening it and without a single mouse click.  

Notice when a sketch contains multiple tabs, their names appear at the top of the 
preview window.  And scroll controls appear when the listing exceeds a single page.
(If you dont have a sketch like this in your sketchbook, find one somewhere and add it.)

To explore this code, clamp the sketchname with a left click.  In clamped mode, the 
sketchname is red, as is the preview window border.  Move the mouse over the tab names
or the scroll controls to locate the portion of the code you're interested in.  

To unclamp, left click anywhere in the left panel.  The sketchname turns green again. 

Open any sketch in a native IDE window with a single right click.

Press 'v' to toggle the sketch list view between alphabetical and last modified time.

Press 's' to search for sketchSearchTerm.

Press 'h' to display keyboard command help.

I run this browser whenever I use Processing.  The animation loop only runs when the
sketch is being used, so it can stay open and idle without consuming resources.

================================================
2.  User Parameters

a. Paths - by default the code browser will look in the sketchbook.  To browse included examples
or installed libraries, change the appropriate boolean values in the code and run again.
Startup is faster with only one path enabled.  

b. Search - its clunky, but returns very useful results.  Set sketchSearchTerm to 
desired term and run agan.  Press 's' to view the result list.                  
   
c. Variables - resize things by changing final ints HEIGHT and WIDTH as desired.  
The sketchname and code listing text size can also be adjusted, as can the sketchname
column width.  Don't monkey with anything else.
*/

//you'll need the apache commons libraries installed
import org.apache.commons.io.filefilter.*;
import org.apache.commons.io.FileUtils;

//these three must be changed for your machine's configuration (I use a Mac)
File sketchpath=new File("/Users/timfulton/Documents/Processing");
File libraries=new File("/Users/timfulton/Documents/Processing/libraries");
File examples=new File("/Applications/Processing.app");

//mostly I'm interested in my own sketches; best to enable just one.
//TODO: MAKE THIS SELECTION INTERACTIVE
boolean includeSketchpath=true;
boolean includeLibraries=false;
boolean includeExamples=false;

//change example term and run again for different search.
String sketchSearchTerm="HashMap";

///////////// begin user-adjustable parameters

//change width and height here, NOT in size()!!
final int WIDTH=1125, HEIGHT=800;//1100,900

final int SKETCHNAME_SIZE=12;//sketchname text size (left panel)
final int CONTENT_LINE_SIZE=13;//codeline text size (right panel)

//increase this if your sketchnames often often exceed about 22 chars.
final int COLUMN_WIDTH=140;
//////////// end user-adjustable parameters

final int CODE_LINE_LENGTH=85;//(roughly) the num of chars/line of code
final int LINE_HEIGHT=14;
final int LINE_NUMBER_SIZE=CONTENT_LINE_SIZE-2;//line nums rendered smaller
final int DISP_LINES=int((HEIGHT-100)/(LINE_HEIGHT))-1;

boolean locked,sortByModified=false,showHelp;

PGraphics helpImage;

ListImage namesByAlpha,namesByMod,activeListImage,searchResults;

ArrayList <Sketch> Sketches=new ArrayList <Sketch>();
ArrayList <Sketch> SketchesByModDate=new ArrayList <Sketch>();
ArrayList <Sketch> FromLibraries=new ArrayList <Sketch>();
ArrayList <Sketch> FromSketchpath=new ArrayList <Sketch>();
ArrayList <Sketch> FromExamples=new ArrayList <Sketch>();
ArrayList AllResults;

Set <File> librariesSet,examplesSet;

int divis,sketchesLOC;//the division between panels, total lines of code
int to=20,screen=0,scrollStart,searchHits;//results scrolling

///////////////////////////////////////////////////////////////////////////////////
//--------------------------------------------------- S E T U P -------------------

public void setup()
{
    size (WIDTH,HEIGHT);
    background (51); 
    rectMode (CORNERS);
    smooth();
    
    //make this a formal pfont, and use a monospace for the code display? 
    textFont(createFont ("Tahoma-11.vlw", SKETCHNAME_SIZE, true));    
    
    String sizer="-";
    while(sizer.length()<CODE_LINE_LENGTH) sizer+="-";
    
    divis=int(width-textWidth(sizer));
    
    librariesSet=new TreeSet();
    examplesSet=new TreeSet();
  
    FromSketchpath=new ArrayList <Sketch>();
    FromLibraries=new ArrayList <Sketch>();
    FromExamples=new ArrayList <Sketch>();
   
    println("including sketchpath - "+includeSketchpath+TAB+"("+sketchpath.getPath()+")");
    println("including libraries - "+includeLibraries+TAB+"("+libraries.getPath()+"/*)");
    println("including examples - "+includeExamples+TAB+"("+examples.getPath()+"/*)\n");

   String []extensions=new String [] {"pde"};
   
   //get the sketchbook
   if (includeSketchpath){
      //returns everything from directory
      File [] sketchpathFiles=sketchpath.listFiles();
     //only need those directories containing a matching .pde file
      for (File f:sketchpathFiles) {
           if (f.isDirectory() && new File(f.getPath()+"/"+f.getName()+".pde").exists()){
               FromSketchpath.add(new Sketch(f));
               }
            }
       Sketches.addAll(FromSketchpath);
       println(FromSketchpath.size()+" sketches created from "+sketchpath.getPath());
      }
   
   //filefilter (Apache's FileUtils) gets all .pde-extended files in /libraries/*  
   if (includeLibraries){
       List<File>QueryResultFiles=(List<File>) FileUtils.listFiles(libraries, extensions, true);  
       //putting each file's parent dir in [Tree]Set elims dupes
       for (File f: QueryResultFiles)  librariesSet.add(f.getParentFile());

       println("QueryResultFiles/librariesSet =  "+QueryResultFiles.size()+" / "+librariesSet.size());
       Enumeration e=Collections.enumeration(librariesSet);
       while (e.hasMoreElements()) FromLibraries.add(new Sketch((File)e.nextElement()));
      
       Sketches.addAll(FromLibraries);
       println(librariesSet.size()+" sketches in the installed libraries (QRF is "+QueryResultFiles.size()+")");
     }
   
    //all of the sketches included in the Processing installation
    if (includeExamples){
       List<File>QueryResultFiles=(List<File>) FileUtils.listFiles(examples, extensions, true);  
       for (File f: QueryResultFiles)  examplesSet.add(f.getParentFile());

       Enumeration e=Collections.enumeration(examplesSet);
       while (e.hasMoreElements()) FromExamples.add(new Sketch((File)e.nextElement()));
    
       Sketches.addAll(FromExamples);
       println(examplesSet.size()+" sketches in the included examples (QRF is "+QueryResultFiles.size()+")");
    }     
    
      //for shits and giggles, total lines of code
      for (Sketch sk: Sketches) sketchesLOC+=sk.getSketchLOC();

      println(Sketches.size()+" Sketch objects created ("+sketchesLOC+" LOC)");
    
   //make a ListImage of this as well.
    namesByAlpha=new ListImage(Sketches,divis,height);

    SketchesByModDate=sortArrayList(Sketches);
  
  makeHelpImage();//create the help screen 
  println("\npress h for help");
  noLoop();
}//end setup

//////////////////////////////////////////////////////////////////////////
//---------------------------------------------------------------- D R A W
public void draw(){
  
  background(51); 
  if (sortByModified) activeListImage=namesByMod;
      else activeListImage=namesByAlpha;
      
  switch(screen){
   
  //------------------------------------------------------------------- c a s e  0
  case 0:
  
    //also calls the activeSketch's display method
    activeListImage.displayListImage();
       
    //if not locked, which sketch object is indicated?
    if (!locked){
        //does isOver on ListImage, sets activeSketch, checks buttons
        activeListImage.checkMousePosition();
      } 
      else{ //if locked, outline code disp panel, check skt buttons and tabstrip  
            strokeWeight(2); stroke(0xffF04949); noFill();     
               rect(divis, 5, width-5, height-5,4);         
            Sketch skt=(Sketch) activeListImage.getActiveSketch();
            skt.checkButtons();
            skt.checkTabStrip();// check the tabstrip first (move to class?)
            redraw(); //necessary??
           }
    break;//end case 0
    
  //a scrollable list of search results
  //--------------------------------------------------  C A S E  1
  case 1:
      
      pushStyle();
        fill(255);
        textSize(19);
          text ("searching sketches for: "+sketchSearchTerm+", "+searchHits+" hits",width/3*2,20);
          text ("new search: change sketchSearchTerm & run again",width/3*2,40);
          text ("u,d - scroll through results", width/3*2,60); 
          text ("c - returns to default view", width/3*2,80); 
        textSize(14);
        scrollStart=constrain(scrollStart,0,AllResults.size()-int(height/14));
        for (int i=0;i<int(height/14);i++){
          text((String)AllResults.get(i+scrollStart),20,20+(LINE_HEIGHT*i));
        }
      popStyle();  
    break;//end case1
  }
  if (showHelp) image(helpImage,50,50);
}//draw
         
//                                                                 D R A W
//////////////////////////////////////////////////////////////////////////


//---------------------------------------------------------------------------------- mouseMoved();
public void mouseMoved() { redraw(); }

//---------------------------------------------------------------------------------- mousePressed();
public void mousePressed() 
{
  //for mac, opens sketch in the ide; works on pc?
  if (mouseButton==RIGHT){
      Sketch se=activeListImage.getActiveSketch();
      String [] args= {se.sketchFolder+"/"+se.toString()+".pde"};
      println("right mouse triggered with String[] args="+args[0]);
      open(args);
      }
 if (mouseButton == LEFT){
     if (locked && mouseX<divis) locked=false;
       else locked=true;
    }
   redraw();
}

//---------------------------------------------------------------------------------- keyPressed();
void keyPressed(){
  if (key=='u'){ scrollStart--; }
  if (key=='d'){ scrollStart ++; }
  if (key=='h') { showHelp=!showHelp; }
  if (key=='v') {  //toggle view alpha/lastmod
       sortByModified = !sortByModified;
       /*must regenerate ListImages when changing view because of object deep/shallow 
       clone issue elsewhere. but, this remedies the vexing wrong sketchname issue*/
       if (sortByModified) namesByMod=new ListImage(sortArrayList(Sketches),divis,height);
           else  namesByAlpha=new ListImage(Sketches,divis,height);
     }
  if (key=='s')  {
    println("\nsearching Sketches for: "+sketchSearchTerm);
    searchSketchesFor(sketchSearchTerm); 
    screen=1;
   }
  //clears search results and returns to the default screen
  if (key=='c') { screen=0; }
  if (key=='q') { exit(); }
  redraw();
}

//returns ArrayList of the Sketches by last modification time.
//---------------------------------------------------------------------------------- sortArrayList(Not)
public ArrayList sortArrayList(ArrayList <Sketch> Not){
      
    //target array, destination for sorted elements
    ArrayList <Sketch> Ordered = new ArrayList<Sketch>(Not.size());                                
    
    //modMils and position in source array
    HashMap <Long,Integer> sortValues = new HashMap < Long,Integer> ();    
    
    //a Long[] of millis - modified (could be opened or created also)
    //array is sorted; then hashmap lookup of original element number.
    Long [] places = new Long[Not.size()];                               
      
    //for sorting, need Long[] and HashMap
    for (int i=0; i<Not.size(); i++){ 
        places[i] =  Not.get(i).getLastModified();
        sortValues.put(places[i],i);//key=modtime, value=pos in unsorted list
      }
       
    //then sort the array of Longs
    Arrays.sort(places,Collections.reverseOrder());  
    
    for(int i=0; i<Not.size(); i++){
       //places now sorted by modMil, tells where in the original array
       //and we add that element from the source arrray to the targ
       Ordered.add(i, Not.get(sortValues.get(places[i])) );                          
      }
      
return Ordered;
}

//help screen rendered as an image, displayed on showHelp
//--------------------------------------------------------------------makeHelpImage()
void makeHelpImage(){
  helpImage=createGraphics(600,300);
  helpImage.beginDraw();
  helpImage.background(0,80);
  helpImage.textFont(createFont ("Tahoma-15.vlw", 15, true));
  helpImage.fill(255);
  helpImage.textSize(16);
  helpImage.text("Commands",20,20);
  helpImage.textSize(15);
  helpImage.text("h - toggles this screen",20,50);
  helpImage.text("v - switches view between alphabetical or last modified",20,75);
  helpImage.text("left mouse button - clamps the active sketch in code display window",20,100);
  helpImage.text("right mouse button - opens sketch in IDE (Mac only)",20,125);
  helpImage.text("s - search (for hardcoded temp search term)",20,150);
  helpImage.text("c - clears the search result screen, returns to default display",20,175);
  helpImage.text("q - quits",20,200);
  helpImage.text("to switch between sketchbook, libraries and examples,",20,225);
  helpImage.text("you must change the boolean values in the code & run again",20,255);
  helpImage.endDraw();
}

//called in keyPressed()
//--------------------------------------------------------- searchSketchesFor(what);
void searchSketchesFor(String what){
  AllResults=new ArrayList<String>();
  searchHits=0;
  for (Sketch st: Sketches){
      if (st.sketchHas(what)) {
        searchHits+=st.getSketchResults().size();
        AllResults.add(st.getName()+".pde has "+st.getSketchResults().size());
        AllResults.addAll(st.getSketchResults());   
        AllResults.add("");
      }  
    }
  // searchResults=new ListImage(AllResults,divis,height);
}

/*
Buttons are elliptical or rectangular
four types: up,down,right,left
the check() method encapsulates calls
to isOver() and then displayButton()
*/

class Button{
  
  boolean overMe;
  float high,wide,startX,startY,cx,cy,ra;
  String type;
  int duFactor=0,lrFactor=0;

//elliptical button constructor
Button (float _cx, float _cy, float _ra,String _type){
  type=_type;
  cx=_cx;
  cy=_cy;
  ra=_ra;
  checkType();
}

//rect button constructor
Button(float _bx,float _by,float _wi,float _hi,String _type){
  type=_type;
  high=_hi;wide=_wi;
  startX=_bx;startY=_by;
  checkType();
}

//sets overMe, calls displayButton
//called by ListImage, displayListImage()
//and by Sketch, displaySketch()
//------------------------------------------------------ void check()
public void check()
{
  overMe = isOver();
  displayButton();
}

//boolean not needed outside this class
//------------------------------------------------------boolean isOver()
public boolean isOver()
{
  boolean overButton=false;
  float mx=mouseX,my=mouseY;
  loop();
  
  if (type.equals("up") || type.equals("down"))
       overButton=sqrt( sq(cx-mx) + sq(cy-my)) < ra/2;
  
   if (type.equals("right") || type.equals("left")) 
       overButton=mx>startX && mx<startX+wide && my>startY-high/2 && my<startY+high/2;
              
   if(!overButton) noLoop();// else no   
       
   return overButton;
}  

//both button styles handled using du/lr factors
//TODO: some ani of button states?
//------------------------------------------------------displayButton();
public void displayButton()
{
   //elliptical button
   if (duFactor!=0){  
     pushStyle();
       stroke(0);
       if (overMe){fill(0,70);strokeWeight(1.5);}
            else{fill(0,30);strokeWeight(.5);}
       line(cx-20,cy,cx,cy+duFactor);
       line(cx+20,cy,cx,cy+duFactor);
       ellipse(cx,cy,50,50);
     popStyle();
     }

   //rect button
   if (lrFactor!=0){
    pushStyle();
     //rectMode(CORNER); 
     rectMode(CENTER); 
     stroke(255);
     if (overMe) {fill(255,50); strokeWeight(1.5);}
          else {fill(255,80);strokeWeight(.5);}     
     rect(startX+wide/2,startY,wide,high,2);
     popStyle();    
  }
}

//down-up and left-right factors...yuck
//------------------------------------------------------------------checkType();
void checkType()
{
 if (type.equals("up")) {duFactor+=-10;}
 if (type.equals("down")){duFactor+=10;}
 if (type.equals("left")){lrFactor+=-10;}
 if (type.equals("right")){lrFactor+=10;}
}

}//class Button

/*
given an ArrayList of Sketch objects and the width and height,
create a clickable image of the names that:
calculates boundaries and location of each object's name,
checks mouseovers and returns indicated Sketch object;
handles left/right scrolling
*/

class ListImage {
      
      PFont pf;
      PGraphics limg;
      Sketch activeSketch;
      Button leftBut,rightBut;
      boolean overListImage,overVisibleListImage;
      float lineHeight=LINE_HEIGHT,topOffset=15,xOff,yOff;
      int   imageHeight,imageWidth,startPosition=0;
      int   textBigness=SKETCHNAME_SIZE,numberOfLines,numberOfColumns;
      ArrayList <Sketch> ial=new ArrayList<Sketch>();
  
ListImage(ArrayList<Sketch> _al,int _wi, int _hi){
    
    ial=_al;
    pf=createFont ("Tahoma-11.vlw", textBigness, true);
    imageHeight=_hi;imageWidth=_wi;
    numberOfLines=int(imageHeight/lineHeight);
    numberOfColumns=int(_al.size()/numberOfLines)+1;
    imageWidth=numberOfColumns*COLUMN_WIDTH;
    makeListImage(_al);
    activeSketch=_al.get(0);
    leftBut=new Button(0,height/2-20,15,80,"left");
    rightBut=new Button(divis-20,height/2-20,15,80,"right");
}

//this class needs to be expanded to handle arraylists of any objects
ListImage(String _content){/*this for string[] data*/}


//--------------------------------------------------------------------------------getters/setters
PImage getImage(){  return limg;}
Sketch getActiveSketch(){ return activeSketch; }
void setXoff(float xo){xOff=xo;}
void setYoff(float yo){yOff=yo;}

//called by checkButtons()
//------------------------------------------------------------------------------imageScroll(int n)
private void imageScroll(int _n)
{
  startPosition+=_n;
  startPosition=constrain(startPosition,(limg.width-divis)*-1,0);
}

//called by checkMousePosition()
//is the mouse over the (visible) listImage?
//--------------------------------------------------------------------------------isOver()
private boolean isOver()
{
   overListImage=false; overVisibleListImage=false;
   float mx=mouseX,my=mouseY;
   //the listImage can be larger than what's visible
   overListImage=(mx>xOff && mx<xOff+limg.width && my>yOff && my<yOff+limg.height);
   
   if (overListImage) overVisibleListImage=(mx<divis);
  
   return overVisibleListImage;
}

//called by checkMousePosition()
//loop & scroll if the mouse is over a button
//--------------------------------------------------------------------------------updateButtons()
private void checkButtons()
{  
  if (leftBut.isOver()){
       loop();
       imageScroll(2);
       }
   else if (rightBut.isOver()){
            loop();
            imageScroll(-2);
           }else noLoop();
    
  redraw();    
}

//called by draw(), case0, !locked
//if mouse isOver ListImage, then checks each 
//Sketch's isOver() and set the activeSketch
//--------------------------------------------------------------------------------checkMousePosition()
public void checkMousePosition()
{
 if (isOver()) {
     for (Sketch se:ial) if (se.isOver(startPosition)) activeSketch=se;
     }
  checkButtons();
}

//called by draw(), if locked (call it displayLockedListImage?)
//displays ListImage at correct startPosition, checks l/r buttons,
//checking, shows activeSketch name in red and calls its display method.
//(call to checkMousePosition() must preceed, else no activeSketch!!)
//--------------------------------------------------------------------------------displayListImage()
public void displayListImage()
{
  image(limg,startPosition,0);
  leftBut.check(); rightBut.check();// leftBut.displayButton(); rightBut.displayButton();
  
  pushStyle();
    if (locked) fill(#DE2424); else fill(#1CFC5D);  //activeSketch's name in red
    
    textSize(SKETCHNAME_SIZE);
    text(activeSketch.displayName,activeSketch.sktNameX+startPosition-1,activeSketch.sktNameY);
  popStyle();
  
  activeSketch.displaySketch();
}

//called by constructor (or an update(w/new list)?)
//--------------------------------------------------------------------------------makeListImage(ArrayList)
private void makeListImage(ArrayList <Sketch> _ial)
{
  int currentLine=0,currentColumn=0;
  ial=_ial;
     //prepare the graphic background
     limg=createGraphics(imageWidth,imageHeight);
     limg.beginDraw();
     limg.noFill();
     limg.stroke(255);
     limg.textFont(pf);
     limg.smooth();
     limg.textSize(textBigness);
     limg.fill(#DBCBCB);
     //calculate the row/column for each sketch
     for (int i=0;i<_ial.size();i++){ 
       if (i>0 && i%numberOfLines==0) {
        currentColumn++;currentLine=0;
        }
      //with row/column, sketches calc their loc. on the image
       Sketch skt=(Sketch) _ial.get(i);
       skt.setLine(currentLine); 
       skt.setColumn(currentColumn);
       skt.calculatePosition();
       //finally, print the name of the sketch on the image
       limg.text(skt.getDisplayName(),currentColumn*COLUMN_WIDTH+3,topOffset+currentLine++*lineHeight);
      }
      limg.endDraw();
} 
  
}//class ListImage

/*
A container class for Processing sketches.  

Sketches are instantiated with a valid sketch directory (File).
Responsible for creating the SketchElement objects (the tabs in
a sketch), calculating its location for the ListImage, creating
the TabGraphic, and handling mouseovers.   
*/
class Sketch{
  
      PGraphics tabStrip;
      Long lastModifiedOn;
      Button upBut, downBut;

      SketchElement activeElement;
      File sketchFolder;//parentFileObject;

      ArrayList SketchSearchResults,Re;
      ArrayList <SketchElement> SketchElements=new ArrayList();
      String name,displayName,parentFileName,fullPathAndName,spacer="    ";
      
      float spacerWidth=textWidth(spacer);
      float sktNameX,sktNameY,sktNameW,sktNameH,topOffset=15;

      int inColumn,atLine,tabGraphicHeight;
      int currentElement,startPosition=0;
      int defaultDisplayElement,sketchLOC;
      
      boolean overCondition,hasHitsFromSearch;
      
Sketch(File _sketchdir){

      sketchFolder=_sketchdir;      
      name=sketchFolder.getName();
      fullPathAndName=sketchFolder.getPath()+"/"+sketchFolder.getName()+".pde";
      
      //(millis) used by the main program's sortArrayList function
      lastModifiedOn=sketchFolder.lastModified();
      upBut = new Button(width-100, height/2-50, 60, "up");
      downBut = new Button(width-100, height/2+50, 60,"down");
      SketchSearchResults=new ArrayList();
      Re=new ArrayList();
      addElements();//add the tabs.
      trimDisplayName();//to fit in col width
      createTabGraphic();//clickable image of tabNames
      setActiveElement(defaultDisplayElement);
}


//------------------------------------------------------------------------------- get-set
//called by searchSketchesFor() in main program
public ArrayList getSketchResults(){return SketchSearchResults;}
//make this return the fullname 
public String toString() {return name;}
//one should be the full name and the other the truncated one.
public String getName() {return displayName;}
public String getDisplayName(){return displayName;}
public long getLastModified(){return lastModifiedOn;}
public boolean hasHitsFromSearch(){return  hasHitsFromSearch;}
public int getSketchLOC(){ return sketchLOC;}
//called by ListImage, makeListImage()
//sets row/col loc calc'd in that class
public void setColumn(int _col){inColumn=_col;}
public void setLine(int _line){atLine=_line;}

//called by checkButton(), these methods call 
//the single scroll(int) method in SketchElement class.
//------------------------------------------------------------------------------ scrolling();
private void scrollUp()  {activeElement.scroll(-1);}
private void scrollDown()  {activeElement.scroll(1);}

//called by ListImage, checkMousePosition()
//Sketch objs know loc on ListImage, but need column offset.
//------------------------------------------------------------------------------ boolean isOver()
public boolean isOver(int _startpos)
{
  startPosition=_startpos;
  overCondition=false;
  
  if (mouseX>sktNameX+startPosition && mouseX<sktNameX+COLUMN_WIDTH+startPosition &&
        mouseY>sktNameY && mouseY<sktNameY+LINE_HEIGHT)
     { overCondition=true; }
     
  return overCondition;
}

//called by ListImage, displayListImage()
//sketch display is code listing, tabstrip, and sometimes buttons
//------------------------------------------------------------------------------ displaySketch()
public void displaySketch()
{ 
  rectMode(CORNERS);
  //this blanks the whole code display panel
  fill(255); noStroke(); 
        rect(divis, tabGraphicHeight, width-4, height-4,4); 
  //then displays the tabs
  image(tabStrip,divis,2);
  //SketchElements handle their own display
  activeElement.displayContent();
  //if content length > display lines, need buttons
  if (activeElement.getContentLength()>DISP_LINES) {upBut.check(); downBut.check();}
}

//called by Sketch class constructor; first gets contents of the
//Sketch's directory, then creates a SketchElement object
//from each valid (.pde and .java) File object.  Finally,
//sets the defaultDisplayElement.
//------------------------------------------------------------------------------ addElements()
private void addElements()
{
    File [] sketchDirContents=sketchFolder.listFiles();
    //not everything in the dir is a valid sketch tab
    for (File f:sketchDirContents) {
       if (f.getName().endsWith(".pde") || f.getName().endsWith(".java")){
           SketchElements.add(new SketchElement(f));
          }   
      }
    for (int i=0;i<SketchElements.size();i++){
        sketchLOC+=SketchElements.get(i).getElementLOC();
        if (SketchElements.get(i).getName().equals(name)){
           defaultDisplayElement=i; 
           setActiveElement(i);
          }
       }
}

//called addElements() and checkTabStrip()
//------------------------------------------------------------------------------ setActiveElement(n)
private void setActiveElement(int n)
{
   if (n>SketchElements.size())  n=0;

  currentElement=n;
  activeElement=SketchElements.get(n);
}

//called in draw(), case0
//buttons activated by hovering, not clicking.
//checks isOver() in the button class
//------------------------------------------------------------------------------ checkButtons();
public void checkButtons()
{
  //simply check if over the image; if so, then check the buttons
  if (upBut.isOver()){ loop(); scrollUp(); } 
     else if (downBut.isOver()){ loop(); scrollDown();}
        else noLoop(); 
}

//called by case0 in draw()
//first check isOver the tabGraphic,
//then check for the active SketchElement
//------------------------------------------------------------------------------ checkTabStrip();
public void checkTabStrip()
{  
  //make whatever the mouse is pointing at the activeElement
  for (int i=0;i<SketchElements.size();i++){
      //(method clears the flag first)
      if (SketchElements.get(i).isOver()) {
           if (i != currentElement) setActiveElement(i);
          }
      }
}

//class constructor call
//creates clickable graphic of tab names (just a ListImage instance?)
//------------------------------------------------------------------------------ createTabGraphic()
private void createTabGraphic()
{
  int tabGraphicLines=0;
  int tabGraphicWidth=width-divis;
  float elementsLength=textWidth(name)+spacerWidth;

  //calc SketchElement x/y's and tabGraphic height
  for (SketchElement se:SketchElements){
       //the first element is the sketchname.
       if (name.equals(se.getName())) {
           se.setHorizPos(3); se.setVertPos(16);
           continue;
           }
        
       //spacerwidth is wonky with many tabs, but leave for now
       elementsLength+=textWidth(se.name)+spacerWidth;
     
       //more tabs increase height of tabgraphic... make smarter.
       if (elementsLength>=tabGraphicWidth){
          elementsLength=0;
          tabGraphicLines+=1;
          }
       se.setHorizPos(int(elementsLength));
       se.setVertPos(16+15*tabGraphicLines);
      }
     
    tabGraphicHeight=20+20*tabGraphicLines;
    
    tabStrip=createGraphics(tabGraphicWidth,tabGraphicHeight);
    tabStrip.beginDraw();
    tabStrip.background(0);
    tabStrip.rect(1,1,tabGraphicWidth-3,tabGraphicHeight-2,4);
    tabStrip.fill(#7B38E8);//purpleish
    tabStrip.text(name,3,15);

     for (SketchElement se:SketchElements){
         if (name.equals(se.getName()))  continue;
              else {
                tabStrip.text(se.getName(),se.getXPos(),se.getYPos());
              }  
       }
         
     tabStrip.endDraw();
}

//called by ListImage class during makeListImage()
//calculates sketchname location, used for isOver()
//----------------------------------------------------------------------------- calculatePosition()
public void calculatePosition()
{
   sktNameX=inColumn*COLUMN_WIDTH+4;
   sktNameY=topOffset+atLine*LINE_HEIGHT;
   sktNameW=textWidth(displayName);
   //need sktNameH??
}

//if name width exceeds column width,
//trim a character at a time then
//make a bit smaller and append ..
//------------------------------------------------------------------------------ trimDisplayName(colwidth)
private void trimDisplayName()
{
  displayName=name;
  if(textWidth(displayName)>COLUMN_WIDTH){
     while (textWidth(displayName)>COLUMN_WIDTH) 
        displayName=displayName.substring(0, displayName.length()-1);
                   
     displayName=displayName.substring(0, displayName.length()-1)+"..";         
    }
}

//called in main program, searchSketchesFor(term)
//------------------------------------------------------------------------------ boolean sketchHas(searchterm);
public boolean sketchHas(String searchTerm)
{
  SketchSearchResults.clear();
  //ArrayList of line numbers as Strings
  Re.clear();
  boolean hasResults=false;  
  for (SketchElement se:SketchElements){
    //if the element contains the term
    if (se.elementContains(searchTerm)){     
      //it has an arraylist of the line numbers 
      Re=se.getTabSearchResults();        
      for (int i=0;i<Re.size();i++){
             //line format is: tab name: line number  line result
             SketchSearchResults.add(se.getName()+" : "+Re.get(i)+(String)se.getLine((Integer)Re.get(i)));
            }
          hasResults=true;
         }
      }
  return hasResults;
}

}//class Sketch

/*
SketchElements are sketch tabs, created by the Sketch class
responsible for getting & displaying content (keeps track of scroll position)
*/
  
class SketchElement{
    
        float lineHeight=15,topOffset=50,elementNameLength;
        float loX,loY,hiX,hiY;
        int startLine=0,scrollPos=0,elementLOC;
        
        String name,trimmedName;
        String[]content;
        
        boolean overName,isSelectedElement;
        ArrayList <String> searchResultLines;
        ArrayList ResultLineNumbers=new ArrayList();

 SketchElement(File f){
      
      File element=f;
      name=element.getName(); 
      
      //take off extension and save trimmed width
      trimmedName=name.substring(0,name.indexOf("."));
      elementNameLength=textWidth(trimmedName);
      
      //in which case can't call loadStrings on data directory
      if (element.isDirectory()) content=element.list();
         else content=loadStrings(element.getPath());
      
      elementLOC=content.length;   
   }

//--------------------------------------------------------- getters & setters
public String getName(){ return trimmedName;}
public float getXPos(){ return loX;}
public float getYPos(){return loY;}
public ArrayList getTabSearchResults(){ return ResultLineNumbers;}

public int getContentLength(){ return content.length;}
public String getLine(int i){ return content[i];}
public int getElementLOC(){ return elementLOC; }

//call by Sketch class, createTabImage()
//--------------------------------------------------------- setHorizPos()
public void setHorizPos(int _x)
{ 
    loX=_x;
    hiX=_x+elementNameLength;
  }

//call by Sketch class, createTabImage()
//--------------------------------------------------------- setVertPos()
public void setVertPos(int _y)
{
    loY=_y;
    hiY=_y+LINE_HEIGHT;
  }

//called by Sketch, checkTabStrip()
//--------------------------------------------------------- boolean isOver()
public boolean isOver()
{
  
  isSelectedElement=false;
  float mx=mouseX,my=mouseY;

  if (mx>loX+divis && mx<hiX+divis && my>loY-LINE_HEIGHT/2 && my<hiY-LINE_HEIGHT/2) isSelectedElement=true;
  
  return isSelectedElement;
}

//called by Sketch, displaySketch()
//--------------------------------------------------------- displayContent()
public void displayContent()
{
  //the default is one viewable page
  int viewContentsLength=DISP_LINES;
  
  //if contentLength < viewable lines, make loop smaller
  if (content.length<DISP_LINES) viewContentsLength=content.length;
 
   //viewContentsLength =  displayLines or if less
   for (int i=0;i<viewContentsLength;i++)
     {
         //line #'s are smaller, less opaque than codeLines
         textSize(LINE_NUMBER_SIZE);
         fill(0,100);
           text((i+scrollPos)+": ",divis+2,i*lineHeight+topOffset);
         
         //the actual lines of code
         textSize(CONTENT_LINE_SIZE);
         fill(0);
           text(content[i+scrollPos],divis+textWidth((scrollPos+i)+": "),i*lineHeight+topOffset);
       }
    
    //position within the code, upper right corner in red
    pushStyle();
      fill(#D85555);
        int upperBound=scrollPos+DISP_LINES;
        if (content.length<upperBound) upperBound=content.length;

        text(scrollPos+" - "+(upperBound)+" / "+ content.length, width-150,topOffset);
    popStyle();
  
  //selected tabelement is blue
  if (isSelectedElement) fill(0xff020CF0); 
       else fill(#7B38E8);
       
  //trimmed is name minus extension
  text(trimmedName,loX+divis,loY+1);
}

//called from Sketch class with pos or neg...
//--------------------------------------------------------- scroll(int n);
public void scroll(int _n)
{
  scrollPos+=_n;  
  scrollPos=constrain(scrollPos,0,content.length-DISP_LINES);
}

//called by Sketch class in sketchHas(term)
//--------------------------------------------------------- boolean elementContains(what) 
public boolean elementContains(String what)
{  
  ResultLineNumbers.clear();
  
  for (int i=0;i<content.length;i++){
   
  //this is an ArrayList of numbers as Strings  
    if (content[i].contains(what)) ResultLineNumbers.add(i);    
    }
  return ResultLineNumbers.size()>0;
}
}//class SketchElement
