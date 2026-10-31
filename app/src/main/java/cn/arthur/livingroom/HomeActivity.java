package cn.arthur.livingroom;

import android.app.*;
import android.os.*;
import android.content.*;
import android.content.pm.*;
import android.graphics.*;
import android.graphics.drawable.*;
import android.net.Uri;
import android.view.*;
import android.widget.*;
import org.json.*;
import java.io.*;
import java.net.*;
import java.text.SimpleDateFormat;
import java.util.*;
import java.util.concurrent.*;
import java.util.regex.*;

/** A silent television home with cached public recommendations. */
public class HomeActivity extends Activity {
  final Handler ui = new Handler();
  final ExecutorService workers = Executors.newFixedThreadPool(3);
  final LinkedHashMap<String,Bitmap> bitmaps = new LinkedHashMap<String,Bitmap>();
  final ArrayList<Film> films = new ArrayList<Film>();
  FrameLayout root; ImageView background; TextView title, description, source, clock, freshness, watch;
  LinearLayout filmRow, appRow; Film selected; boolean active, loading, refreshFailed; long lastRefresh, lastSuccess;
  static final long REFRESH_INTERVAL = 4*60*60*1000L;
  static final long CAROUSEL_INTERVAL = 30000L;
  int heroRequest; float unit; View firstCard;
  final String[][] channels = {{"movie","电影"},{"choice","精选"},{"tv","电视剧"},{"cartoon","动漫"},{"variety","综艺"},{"doco","纪录片"}};
  final String[][] apps = {{"com.ktcp.launcher","腾讯视频"},{"com.xiaodianshi.tv.yst","哔哩哔哩"},{"com.gitvvideo.skyworthopen","奇异果"},{"com.hunantv.market","芒果 TV"},{"com.skyworthdigital.mediarender","投屏"},{"org.xbmc.kodi","Kodi"}};
  static String originalImage(String value){int transform=value.indexOf("?imageMogr2/");return transform<0?value:value.substring(0,transform);}
  static class Film { String title, description, image, url, category; Film(JSONObject o) {title=o.optString("title");description=o.optString("description");image=originalImage(o.optString("image"));url=o.optString("url");category=o.optString("category");} JSONObject json() throws Exception {JSONObject o=new JSONObject();o.put("title",title);o.put("description",description);o.put("image",image);o.put("url",url);o.put("category",category);return o;} }
  int p(float n){return Math.round(n*unit);} int c(String s){return Color.parseColor(s);}
  public void onCreate(Bundle state){super.onCreate(state);getWindow().addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON);unit=getResources().getDisplayMetrics().widthPixels/960f;lastSuccess=getSharedPreferences("feed",0).getLong("success",0);build();seedImages();readFeed();renderFilms();updateFreshness();}
  protected void onResume(){super.onResume();active=true;ui.removeCallbacks(tick);ui.post(tick);restartCarousel();if(System.currentTimeMillis()-lastRefresh>=REFRESH_INTERVAL)refresh();}
  protected void onPause(){active=false;ui.removeCallbacks(tick);ui.removeCallbacks(carousel);super.onPause();}
  protected void onDestroy(){ui.removeCallbacksAndMessages(null);workers.shutdownNow();super.onDestroy();}
  final Runnable tick=new Runnable(){public void run(){if(!active)return;clock.setText(new SimpleDateFormat("HH:mm",Locale.CHINA).format(new Date()));if(System.currentTimeMillis()-lastRefresh>=REFRESH_INTERVAL)refresh();ui.postDelayed(this,15000);}};
  // Clip child imagery inside the border, including the bottom gradient and label.
  class PosterCard extends FrameLayout {
    final Path mask=new Path(); final RectF bounds=new RectF();
    PosterCard(){super(HomeActivity.this);}
    protected void dispatchDraw(Canvas canvas){
      int save=canvas.save();float inset=p(2);bounds.set(inset,inset,getWidth()-inset,getHeight()-inset);
      mask.reset();mask.addRoundRect(bounds,p(11),p(11),Path.Direction.CW);canvas.clipPath(mask);
      super.dispatchDraw(canvas);canvas.restoreToCount(save);
    }
  }
  void restartCarousel(){ui.removeCallbacks(carousel);if(active)ui.postDelayed(carousel,CAROUSEL_INTERVAL);}
  final Runnable carousel=new Runnable(){public void run(){
    if(!active)return;
    if(hasWindowFocus()&&films.size()>1&&(watch==null||!watch.hasFocus())){
      int next=(films.indexOf(selected)+1)%films.size();Film film=films.get(next);
      if(filmRow.hasFocus())filmRow.getChildAt(next).requestFocus();else select(film);
      android.util.Log.i("LivingRoom","Carousel selected "+next);
    }
    restartCarousel();
  }};
  public boolean dispatchKeyEvent(KeyEvent event){if(event.getAction()==KeyEvent.ACTION_DOWN)restartCarousel();return super.dispatchKeyEvent(event);}
  public boolean dispatchTouchEvent(android.view.MotionEvent event){if(event.getAction()==android.view.MotionEvent.ACTION_DOWN)restartCarousel();return super.dispatchTouchEvent(event);}
  public void onWindowFocusChanged(boolean focused){super.onWindowFocusChanged(focused);if(focused)restartCarousel();else ui.removeCallbacks(carousel);}
  void updateFreshness(){if(freshness==null)return;if(loading)freshness.setText("正在更新腾讯精选…");else if(lastSuccess>0)freshness.setText((refreshFailed?"离线推荐 · ":"推荐更新于 ")+new SimpleDateFormat("MM-dd HH:mm",Locale.CHINA).format(new Date(lastSuccess)));else freshness.setText(refreshFailed?"离线精选":"腾讯公开精选");}
  GradientDrawable panel(int color,int stroke){GradientDrawable d=new GradientDrawable();d.setColor(color);d.setCornerRadius(p(13));if(stroke!=0)d.setStroke(p(2),stroke);return d;}
  TextView text(String value,float size,int color){TextView t=new TextView(this);t.setText(value);t.setTextColor(color);t.setTextSize(android.util.TypedValue.COMPLEX_UNIT_PX,p(size));t.setTypeface(Typeface.create("sans-serif",Typeface.NORMAL));t.setIncludeFontPadding(false);return t;}
  void at(View v,int w,int h,int x,int y){FrameLayout.LayoutParams lp=new FrameLayout.LayoutParams(w<0?w:p(w),h<0?h:p(h));lp.leftMargin=p(x);lp.topMargin=p(y);root.addView(v,lp);}
  void focusable(final View v,final int base,final Runnable action){v.setFocusable(true);v.setClickable(true);v.setSoundEffectsEnabled(false);v.setBackground(panel(base,0));v.setOnFocusChangeListener(new View.OnFocusChangeListener(){public void onFocusChange(View x,boolean focused){x.setBackground(panel(focused?(base==c("#E8EEF7")?Color.WHITE:c("#45536A")):base,focused?Color.WHITE:0));x.animate().scaleX(focused?1.035f:1).scaleY(focused?1.035f:1).setDuration(140).start();if(focused&&action!=null)action.run();}});}
  void build(){
    root=new FrameLayout(this);root.setBackgroundColor(c("#090E18"));setContentView(root);
    background=new ImageView(this);background.setScaleType(ImageView.ScaleType.CENTER_CROP);at(background,-1,400,0,0);
    View shade=new View(this);shade.setBackground(new GradientDrawable(GradientDrawable.Orientation.LEFT_RIGHT,new int[]{c("#EB08101B"),c("#7208101B"),c("#1208101B")}));at(shade,-1,-1,0,0);
    View bottom=new View(this);bottom.setBackground(new GradientDrawable(GradientDrawable.Orientation.TOP_BOTTOM,new int[]{0,c("#20080D16"),c("#FF080D16")}));at(bottom,-1,-1,0,0);
    TextView brand=text("客厅",23,Color.WHITE);brand.setTypeface(Typeface.create("sans-serif-medium",Typeface.NORMAL));at(brand,100,34,40,25);
    TextView eyebrow=text("为今晚选一部好片",11,c("#BEC8D7"));at(eyebrow,180,24,118,34);
    clock=text("",20,Color.WHITE);clock.setGravity(Gravity.RIGHT);at(clock,90,30,720,27);
    TextView settings=text("设置",13,Color.WHITE);settings.setGravity(Gravity.CENTER);focusable(settings,c("#55333D4E"),null);settings.setOnClickListener(new View.OnClickListener(){public void onClick(View v){openSettings();}});at(settings,72,34,840,24);
    source=text("腾讯视频 · 公开精选",11,c("#BFCADB"));at(source,510,22,42,100);
    title=text("让客厅，回到电影。",38,Color.WHITE);title.setMaxLines(2);title.setTypeface(Typeface.create("sans-serif-medium",Typeface.NORMAL));at(title,590,96,40,130);
    description=text("正在加载影视精选",13,c("#D2D9E5"));description.setMaxLines(2);at(description,500,42,42,228);
    watch=text("在腾讯视频查看  ›",13,c("#151D2B"));watch.setGravity(Gravity.CENTER);focusable(watch,c("#E8EEF7"),null);watch.setOnClickListener(new View.OnClickListener(){public void onClick(View v){openFilm(selected);}});at(watch,170,35,42,280);
    TextView rowLabel=text("今晚看什么",15,Color.WHITE);at(rowLabel,180,25,42,332);
    freshness=text("腾讯公开精选",10,c("#A8B5C8"));freshness.setGravity(Gravity.RIGHT);at(freshness,260,20,655,337);
    HorizontalScrollView filmScroll=new HorizontalScrollView(this);filmScroll.setHorizontalScrollBarEnabled(false);filmScroll.setClipToPadding(false);filmScroll.setPadding(p(40),p(5),p(40),p(7));filmRow=new LinearLayout(this);filmRow.setOrientation(LinearLayout.HORIZONTAL);filmRow.setClipChildren(false);filmRow.setClipToPadding(false);filmScroll.addView(filmRow);at(filmScroll,-1,112,0,358);
    HorizontalScrollView appScroll=new HorizontalScrollView(this);appScroll.setHorizontalScrollBarEnabled(false);appScroll.setPadding(p(40),p(5),p(40),p(5));appRow=new LinearLayout(this);appRow.setOrientation(LinearLayout.HORIZONTAL);appScroll.addView(appRow);at(appScroll,-1,63,0,473);
    for(final String[] a:apps){try{final Drawable icon=getPackageManager().getApplicationIcon(a[0]);LinearLayout tile=new LinearLayout(this);tile.setGravity(Gravity.CENTER_VERTICAL);tile.setPadding(p(10),p(5),p(12),p(5));ImageView iv=new ImageView(this);iv.setImageDrawable(icon);tile.addView(iv,new LinearLayout.LayoutParams(p(32),p(32)));TextView label=text(a[1],12,Color.WHITE);LinearLayout.LayoutParams tl=new LinearLayout.LayoutParams(-2,-2);tl.leftMargin=p(8);tile.addView(label,tl);focusable(tile,c("#B52D3646"),null);tile.setOnFocusChangeListener(appFocus(tile,label));tile.setOnClickListener(new View.OnClickListener(){public void onClick(View v){openApp(a[0]);}});LinearLayout.LayoutParams lp=new LinearLayout.LayoutParams(p(134),p(47));lp.rightMargin=p(10);appRow.addView(tile,lp);}catch(Exception ignored){}}
    TextView all=text("全部应用  ›",12,Color.WHITE);all.setGravity(Gravity.CENTER);focusable(all,c("#B52D3646"),null);all.setOnClickListener(new View.OnClickListener(){public void onClick(View v){showApps();}});appRow.addView(all,new LinearLayout.LayoutParams(p(120),p(47)));
  }
  View.OnFocusChangeListener appFocus(final View tile,final TextView label){return new View.OnFocusChangeListener(){public void onFocusChange(View v,boolean f){v.setBackground(panel(f?c("#F1F5FB"):c("#B52D3646"),f?Color.WHITE:0));label.setTextColor(f?c("#172033"):Color.WHITE);v.animate().scaleX(f?1.035f:1).scaleY(f?1.035f:1).setDuration(130).start();}};}
  void renderFilms(){filmRow.removeAllViews();firstCard=null;for(final Film film:films){FrameLayout card=new PosterCard();card.setPadding(p(2),p(2),p(2),p(2));ImageView poster=new ImageView(this);poster.setScaleType(ImageView.ScaleType.CENTER_CROP);card.addView(poster,new FrameLayout.LayoutParams(-1,-1));View gradient=new View(this);gradient.setBackground(new GradientDrawable(GradientDrawable.Orientation.TOP_BOTTOM,new int[]{0,c("#F2081019")}));FrameLayout.LayoutParams gp=new FrameLayout.LayoutParams(-1,p(50),Gravity.BOTTOM);card.addView(gradient,gp);TextView label=text(film.title,12,Color.WHITE);label.setMaxLines(1);label.setEllipsize(android.text.TextUtils.TruncateAt.END);FrameLayout.LayoutParams lp=new FrameLayout.LayoutParams(-1,p(23),Gravity.BOTTOM);lp.leftMargin=p(10);lp.rightMargin=p(8);card.addView(label,lp);focusable(card,c("#334050"),new Runnable(){public void run(){select(film);}});card.setOnClickListener(new View.OnClickListener(){public void onClick(View v){openFilm(film);}});LinearLayout.LayoutParams cp=new LinearLayout.LayoutParams(p(177),p(98));cp.rightMargin=p(12);filmRow.addView(card,cp);loadImage(film.image,poster,false,0);if(firstCard==null)firstCard=card;}if(!films.isEmpty())select(films.get(0));if(firstCard!=null)firstCard.requestFocus();restartCarousel();}
  void select(Film f){selected=f;title.setText(f.title);description.setText(f.description);source.setText("腾讯视频 · "+("精选".equals(f.category)?"公开精选":f.category+"精选"));loadImage(f.image,background,true,++heroRequest);}
  boolean allowedImage(String value){try{URL u=new URL(value);String host=u.getHost();return "https".equals(u.getProtocol())&&(host.endsWith(".qpic.cn")||host.endsWith(".gtimg.cn")||host.endsWith(".qq.com"));}catch(Exception e){return false;}}
  void loadImage(final String url,final ImageView view,final boolean hero,final int request){
    if(!allowedImage(url))return;
    final Bitmap cached;
    synchronized(bitmaps){cached=bitmaps.get(url);}
    if(cached!=null){view.setImageBitmap(cached);return;}
    workers.execute(new Runnable(){public void run(){try{
      File cacheFile=new File(getCacheDir(),"poster-"+Integer.toHexString(url.hashCode())+".jpg");
      byte[] data;
      if(cacheFile.exists()){
        FileInputStream input=new FileInputStream(cacheFile);
        ByteArrayOutputStream buffer=new ByteArrayOutputStream();byte[] part=new byte[8192];int len;
        while((len=input.read(part))!=-1)buffer.write(part,0,len);
        input.close();data=buffer.toByteArray();
      }else{
        data=download(url,10*1024*1024);
        FileOutputStream disk=new FileOutputStream(cacheFile);disk.write(data);disk.close();
        File[] old=getCacheDir().listFiles();
        if(old!=null&&old.length>32){Arrays.sort(old,new Comparator<File>(){public int compare(File a,File b){return Long.compare(a.lastModified(),b.lastModified());}});for(int k=0;k<old.length-24;k++)if(old[k].getName().startsWith("poster-"))old[k].delete();}
      }
      BitmapFactory.Options bounds=new BitmapFactory.Options();bounds.inJustDecodeBounds=true;
      BitmapFactory.decodeByteArray(data,0,data.length,bounds);
      BitmapFactory.Options options=new BitmapFactory.Options();options.inPreferredConfig=Bitmap.Config.ARGB_8888;
      options.inSampleSize=1;
      while(bounds.outWidth/(options.inSampleSize*2)>=1920)options.inSampleSize*=2;
      final Bitmap b=BitmapFactory.decodeByteArray(data,0,data.length,options);
      if(b==null)return;
      synchronized(bitmaps){if(bitmaps.size()>=8)bitmaps.remove(bitmaps.keySet().iterator().next());bitmaps.put(url,b);}
      android.util.Log.i("LivingRoom","Poster decoded "+b.getWidth()+"x"+b.getHeight());
      ui.post(new Runnable(){public void run(){if(isFinishing()||(hero&&request!=heroRequest))return;view.setImageBitmap(b);}});
    }catch(Exception ignored){}}});
  }
  byte[] download(String address,int limit)throws Exception{HttpURLConnection cn=(HttpURLConnection)new URL(address).openConnection();cn.setConnectTimeout(9000);cn.setReadTimeout(12000);cn.setRequestProperty("User-Agent","Mozilla/5.0");cn.setRequestProperty("Referer","https://v.qq.com/");try{if(cn.getResponseCode()!=200)throw new IOException("HTTP "+cn.getResponseCode());InputStream in=cn.getInputStream();ByteArrayOutputStream out=new ByteArrayOutputStream();byte[] buf=new byte[8192];int n;while((n=in.read(buf))!=-1){if(out.size()+n>limit)throw new IOException("size limit");out.write(buf,0,n);}in.close();return out.toByteArray();}finally{cn.disconnect();}}
  void seedImages(){try{InputStream in=getAssets().open("feed.json");ByteArrayOutputStream out=new ByteArrayOutputStream();byte[] bytes=new byte[4096];int n;while((n=in.read(bytes))!=-1)out.write(bytes,0,n);in.close();JSONArray rows=new JSONArray(out.toString("UTF-8"));for(int i=0;i<rows.length();i++){JSONObject row=rows.getJSONObject(i);String asset=row.optString("asset");if(asset.length()==0)continue;InputStream img=getAssets().open(asset);Bitmap b=BitmapFactory.decodeStream(img);img.close();if(b!=null)bitmaps.put(row.optString("image"),b);}}catch(Exception ignored){}} void readFeed(){try{File f=new File(getFilesDir(),"feed.json");InputStream in=f.exists()?new FileInputStream(f):getAssets().open("feed.json");ByteArrayOutputStream out=new ByteArrayOutputStream();byte[] b=new byte[4096];int n;while((n=in.read(b))!=-1)out.write(b,0,n);in.close();JSONArray rows=new JSONArray(out.toString("UTF-8"));for(int i=0;i<rows.length();i++)films.add(new Film(rows.getJSONObject(i)));}catch(Exception e){description.setText("暂时无法读取推荐，可直接打开下方应用");}}
  String focusField(String body,String key){
    Matcher field=Pattern.compile("(?:^|,)"+key+":(\"(?:\\\\.|[^\"\\\\])*\")").matcher(body);
    if(!field.find())return "";
    try{return new JSONArray("["+field.group(1)+"]").getString(0);}catch(Exception e){return "";}
  }
  void refresh(){
    if(loading)return;loading=true;updateFreshness();
    workers.execute(new Runnable(){public void run(){
      final ArrayList<Film> fresh=new ArrayList<Film>();HashSet<String> urls=new HashSet<String>();
      for(String[] channel:channels){if(fresh.size()>=10)break;try{
        String html=new String(download("https://v.qq.com/channel/"+channel[0],2*1024*1024),"UTF-8");
        // Public server-rendered focus cards carry more recommendations than JSON-LD.
        Matcher focus=Pattern.compile("\\{id:\"([A-Za-z0-9]+)\",type:\"focus\",(.{0,6000}?)cutJumpUrl:\"(https://v\\.qq\\.com/x/cover/[A-Za-z0-9]+\\.html)\"",Pattern.DOTALL).matcher(html);
        while(focus.find()&&fresh.size()<10){
          String body=focus.group(2),link=focus.group(3),image=originalImage(focusField(body,"coverPic")),name=focusField(body,"mzTitle");
          if(name.length()==0||!allowedImage(image)||!urls.add(link))continue;
          JSONObject row=new JSONObject();row.put("title",name);row.put("description",focusField(body,"subTitle"));row.put("image",image);row.put("url",link);row.put("category",channel[1]);fresh.add(new Film(row));
        }
        Matcher m=Pattern.compile("<script[^>]*type=[\"']application/ld\\+json[\"'][^>]*>(.*?)</script>",Pattern.DOTALL).matcher(html);
        while(m.find()){
          JSONObject ld=new JSONObject(m.group(1));JSONArray graph=ld.optJSONArray("@graph");if(graph==null)continue;
          for(int g=0;g<graph.length();g++){
            JSONObject block=graph.optJSONObject(g);if(block==null||!"ItemList".equals(block.optString("@type")))continue;
            JSONArray items=block.optJSONArray("itemListElement");if(items==null)continue;
            for(int j=0;j<items.length();j++){
              JSONObject item=items.getJSONObject(j).optJSONObject("item");if(item==null)continue;
              String link=item.optString("url"),image=originalImage(item.optString("image"));
              if(fresh.size()>=10||!link.startsWith("https://v.qq.com/x/cover/")||!allowedImage(image)||!urls.add(link))continue;
              JSONObject f=new JSONObject();f.put("title",item.optString("name"));f.put("description",item.optString("description"));f.put("image",image);f.put("url",link);f.put("category",channel[1]);fresh.add(new Film(f));
            }
          }
        }
      }catch(Exception ignored){}}
      if(fresh.size()>0){
        final long fetchedAt=System.currentTimeMillis();
        android.util.Log.i("LivingRoom","Public feed refreshed: "+fresh.size()+" titles");
        try{
          JSONArray array=new JSONArray();for(Film f:fresh)array.put(f.json());
          File temp=new File(getFilesDir(),"feed.tmp");FileOutputStream out=new FileOutputStream(temp);out.write(array.toString().getBytes("UTF-8"));out.close();
          if(temp.renameTo(new File(getFilesDir(),"feed.json")))getSharedPreferences("feed",0).edit().putLong("success",fetchedAt).apply();
        }catch(Exception ignored){}
        ui.post(new Runnable(){public void run(){if(isFinishing())return;films.clear();films.addAll(fresh);lastRefresh=fetchedAt;lastSuccess=fetchedAt;loading=false;refreshFailed=false;if(active)renderFilms();updateFreshness();}});
      }else ui.post(new Runnable(){public void run(){if(isFinishing())return;loading=false;refreshFailed=true;lastRefresh=System.currentTimeMillis()-REFRESH_INTERVAL+60*60*1000L;updateFreshness();}});
    }});
  }
  void openFilm(final Film f){
    if(f==null){openApp("com.ktcp.launcher");return;}
    try{
      Matcher match=Pattern.compile("https://v\\.qq\\.com/x/cover/([A-Za-z0-9]+)\\.html").matcher(f.url);
      if(!match.matches())throw new IllegalArgumentException();
      Uri uri=Uri.parse("tenvideo2://?action=1&cover_id="+match.group(1));
      Intent intent=new Intent("com.tencent.qqlivetv.open",uri);
      intent.setPackage("com.ktcp.launcher");
      intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK | Intent.FLAG_ACTIVITY_TASK_ON_HOME);
      startActivity(intent);
    }catch(Exception e){Toast.makeText(this,"无法直达片详情，打开腾讯视频首页",Toast.LENGTH_SHORT).show();openApp("com.ktcp.launcher");}
  }
  void openApp(String pkg){try{Intent i;if("com.ktcp.launcher".equals(pkg))i=new Intent().setComponent(new ComponentName(pkg,"com.ktcp.launcher.activity.LauncherMainActivity")).addFlags(Intent.FLAG_ACTIVITY_TASK_ON_HOME);else i=getPackageManager().getLaunchIntentForPackage(pkg);if(i==null)throw new Exception();i.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK);startActivity(i);}catch(Exception e){Toast.makeText(this,"暂时无法打开这个应用",Toast.LENGTH_SHORT).show();}}
  void openSettings(){try{startActivity(new Intent().setComponent(new ComponentName("com.skyworthdigital.settings","com.skyworthdigital.settings.activity.MainActivity")));}catch(Exception e){try{startActivity(new Intent(android.provider.Settings.ACTION_SETTINGS));}catch(Exception ignored){}}}
  void showApps(){Intent query=new Intent(Intent.ACTION_MAIN);query.addCategory(Intent.CATEGORY_LAUNCHER);final ArrayList<ResolveInfo> list=new ArrayList<ResolveInfo>(getPackageManager().queryIntentActivities(query,0));Collections.sort(list,new ResolveInfo.DisplayNameComparator(getPackageManager()));String[] names=new String[list.size()];for(int i=0;i<names.length;i++)names[i]=list.get(i).loadLabel(getPackageManager()).toString();new AlertDialog.Builder(this).setTitle("全部应用").setItems(names,new DialogInterface.OnClickListener(){public void onClick(DialogInterface d,int pos){ResolveInfo r=list.get(pos);try{startActivity(new Intent().setComponent(new ComponentName(r.activityInfo.packageName,r.activityInfo.name)));}catch(Exception ignored){}}}).setNegativeButton("返回",null).show();}
  public void onBackPressed(){if(firstCard!=null)firstCard.requestFocus();restartCarousel();}
}
