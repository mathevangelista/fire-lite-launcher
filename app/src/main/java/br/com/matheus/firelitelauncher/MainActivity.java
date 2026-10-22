package br.com.matheus.firelitelauncher;

import android.app.Activity;
import android.content.ActivityNotFoundException;
import android.content.Intent;
import android.content.pm.ApplicationInfo;
import android.content.pm.PackageManager;
import android.graphics.Canvas;
import android.graphics.Color;
import android.graphics.LinearGradient;
import android.graphics.Paint;
import android.graphics.Path;
import android.graphics.Shader;
import android.graphics.Typeface;
import android.graphics.drawable.GradientDrawable;
import android.os.Bundle;
import android.provider.Settings;
import android.text.TextUtils;
import android.util.DisplayMetrics;
import android.view.Gravity;
import android.view.View;
import android.view.ViewGroup;
import android.widget.FrameLayout;
import android.widget.LinearLayout;
import android.widget.ScrollView;
import android.widget.TextClock;
import android.widget.TextView;
import android.widget.Toast;

import java.util.ArrayList;
import java.util.Collections;
import java.util.Comparator;
import java.util.HashSet;
import java.util.List;
import java.util.Set;

/**
 * Launcher alternativo de uso manual, criado para o Fire TV Stick Lite / Fire OS 7.
 * Nao intercepta HOME, nao altera pacotes Amazon e nao executa tarefas em background.
 */
public final class MainActivity extends Activity {

    private static final int BACKGROUND = Color.rgb(7, 17, 31);
    private static final int WHITE = Color.WHITE;
    private static final int LIGHT_GREY = Color.rgb(189, 201, 217);
    private static final int BLUE_FOCUS = Color.rgb(91, 183, 255);

    private FrameLayout root;
    private View currentContent;
    private View netflixTile;
    private boolean showingApps;
    private float density;

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        density = getResources().getDisplayMetrics().density;
        getWindow().getDecorView().setSystemUiVisibility(
                View.SYSTEM_UI_FLAG_FULLSCREEN
                        | View.SYSTEM_UI_FLAG_HIDE_NAVIGATION
                        | View.SYSTEM_UI_FLAG_IMMERSIVE_STICKY);

        root = new FrameLayout(this);
        root.setBackgroundColor(BACKGROUND);
        root.setClipChildren(false);
        root.addView(new DarkLandscape(this), new FrameLayout.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.MATCH_PARENT));
        setContentView(root);
        showHome();
    }

    private int dp(float value) {
        return Math.round(density * value);
    }

    private void showHome() {
        showingApps = false;
        if (currentContent != null) {
            root.removeView(currentContent);
        }

        FrameLayout screen = new FrameLayout(this);
        screen.setClipChildren(false);
        root.addView(screen, new FrameLayout.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.MATCH_PARENT));
        currentContent = screen;

        addHeader(screen);

        DisplayMetrics metrics = getResources().getDisplayMetrics();
        int usableWidth = metrics.widthPixels - dp(68);
        int contentWidth = Math.min(dp(800), usableWidth);
        int smallRowWidth = Math.min(dp(560), usableWidth);

        LinearLayout center = new LinearLayout(this);
        center.setOrientation(LinearLayout.VERTICAL);
        center.setGravity(Gravity.CENTER_HORIZONTAL);
        center.setClipChildren(false);
        FrameLayout.LayoutParams centerParams = new FrameLayout.LayoutParams(
                contentWidth, ViewGroup.LayoutParams.WRAP_CONTENT, Gravity.CENTER);
        screen.addView(center, centerParams);

        LinearLayout mainRow = new LinearLayout(this);
        mainRow.setGravity(Gravity.CENTER);
        mainRow.setClipChildren(false);
        center.addView(mainRow, new LinearLayout.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT, dp(206)));

        LinearLayout netflix = createTile(
                new int[]{0xff090f18, 0xff05080e}, 18, 3,
                () -> openApp("Netflix", "com.netflix.ninja"));
        netflixTile = netflix;
        TextView netflixText = text("NETFLIX", 57, 0xffe50914, Typeface.BOLD);
        netflixText.setTypeface(Typeface.create("sans-serif-condensed", Typeface.BOLD));
        netflix.addView(netflixText);
        LinearLayout.LayoutParams bigA = new LinearLayout.LayoutParams(0, dp(202), 1f);
        bigA.setMargins(dp(8), 0, dp(8), 0);
        mainRow.addView(netflix, bigA);

        LinearLayout claro = createTile(
                new int[]{0xfff51418, 0xffb80612}, 18, 3,
                () -> openApp("Claro TV", "br.com.claro.now.smarttvclient"));
        claro.addView(text("Claro", 64, WHITE, Typeface.BOLD));
        claro.addView(text("TV", 36, WHITE, Typeface.BOLD));
        LinearLayout.LayoutParams bigB = new LinearLayout.LayoutParams(0, dp(202), 1f);
        bigB.setMargins(dp(8), 0, dp(8), 0);
        mainRow.addView(claro, bigB);

        View gap = new View(this);
        center.addView(gap, new LinearLayout.LayoutParams(1, dp(24)));

        LinearLayout smallRow = new LinearLayout(this);
        smallRow.setGravity(Gravity.CENTER);
        smallRow.setClipChildren(false);
        LinearLayout.LayoutParams smallRowParams = new LinearLayout.LayoutParams(
                smallRowWidth, dp(112));
        center.addView(smallRow, smallRowParams);

        LinearLayout youtube = createTile(
                new int[]{0xff14243c, 0xff0b1423}, 15, 2,
                () -> openApp("YouTube", "com.amazon.firetv.youtube", "com.google.android.youtube.tv"));
        youtube.addView(text("▶", 35, 0xffff252b, Typeface.BOLD));
        youtube.addView(text("YouTube", 20, WHITE, Typeface.BOLD));
        addSmallTile(smallRow, youtube);

        LinearLayout primeVideo = createTile(
                new int[]{0xff0b69b4, 0xff083163}, 15, 2,
                this::openPrimeVideo);
        primeVideo.addView(text("prime video", 23, 0xffe8f4ff, Typeface.BOLD));
        addSmallTile(smallRow, primeVideo);

        LinearLayout apps = createTile(
                new int[]{0xff253247, 0xff101a2b}, 15, 2,
                this::showApps);
        apps.addView(text("▦", 35, 0xffc2d1e4, Typeface.NORMAL));
        apps.addView(text("Apps", 19, LIGHT_GREY, Typeface.NORMAL));
        addSmallTile(smallRow, apps);

        netflix.setNextFocusRightId(claro.getId());
        netflix.setNextFocusDownId(youtube.getId());
        claro.setNextFocusLeftId(netflix.getId());
        claro.setNextFocusDownId(primeVideo.getId());
        youtube.setNextFocusUpId(netflix.getId());
        youtube.setNextFocusRightId(primeVideo.getId());
        primeVideo.setNextFocusUpId(claro.getId());
        primeVideo.setNextFocusLeftId(youtube.getId());
        primeVideo.setNextFocusRightId(apps.getId());
        apps.setNextFocusUpId(claro.getId());
        apps.setNextFocusLeftId(primeVideo.getId());

        netflix.post(netflix::requestFocus);
    }

    private void addHeader(FrameLayout screen) {
        LinearLayout header = new LinearLayout(this);
        header.setOrientation(LinearLayout.HORIZONTAL);
        header.setGravity(Gravity.CENTER_VERTICAL);
        header.setPadding(dp(42), 0, dp(42), 0);
        FrameLayout.LayoutParams headerParams = new FrameLayout.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT, dp(72), Gravity.TOP);
        headerParams.topMargin = dp(8);
        screen.addView(header, headerParams);

        TextView brand = text("Fire TV  Stick Lite", 24, WHITE, Typeface.NORMAL);
        brand.setGravity(Gravity.CENTER_VERTICAL | Gravity.START);
        header.addView(brand, new LinearLayout.LayoutParams(0,
                ViewGroup.LayoutParams.MATCH_PARENT, 1f));

        TextView settingsButton = text("⚙", 29, LIGHT_GREY, Typeface.NORMAL);
        settingsButton.setGravity(Gravity.CENTER);
        settingsButton.setContentDescription("Configurações");
        settingsButton.setFocusable(true);
        settingsButton.setClickable(true);
        settingsButton.setId(View.generateViewId());
        settingsButton.setOnClickListener(view -> openSettings());
        settingsButton.setOnFocusChangeListener((view, focused) ->
                settingsButton.setTextColor(focused ? BLUE_FOCUS : LIGHT_GREY));
        header.addView(settingsButton, new LinearLayout.LayoutParams(dp(48), dp(48)));

        TextView wifi = text("⌁", 29, LIGHT_GREY, Typeface.NORMAL);
        wifi.setGravity(Gravity.CENTER);
        wifi.setContentDescription("Indicador decorativo de rede; não informa o estado da conexão");
        header.addView(wifi, new LinearLayout.LayoutParams(dp(42), dp(48)));

        TextClock clock = new TextClock(this);
        clock.setFormat12Hour("HH:mm");
        clock.setFormat24Hour("HH:mm");
        clock.setTextSize(23);
        clock.setTextColor(LIGHT_GREY);
        clock.setGravity(Gravity.CENTER);
        header.addView(clock, new LinearLayout.LayoutParams(dp(86), dp(48)));
    }

    private TextView text(String value, int sp, int color, int weight) {
        TextView result = new TextView(this);
        result.setText(value);
        result.setTextColor(color);
        result.setTextSize(sp);
        result.setTypeface(Typeface.create("sans-serif", weight));
        result.setGravity(Gravity.CENTER);
        result.setIncludeFontPadding(false);
        result.setSingleLine(true);
        result.setEllipsize(TextUtils.TruncateAt.END);
        return result;
    }

    private LinearLayout createTile(int[] colors, int radius, int stroke, Runnable onClick) {
        LinearLayout card = new LinearLayout(this);
        card.setId(View.generateViewId());
        card.setOrientation(LinearLayout.VERTICAL);
        card.setGravity(Gravity.CENTER);
        card.setPadding(dp(10), dp(8), dp(10), dp(8));
        card.setFocusable(true);
        card.setClickable(true);
        card.setClipChildren(false);
        card.setContentDescription("Abrir aplicativo");
        setCardAppearance(card, colors, radius, stroke, false);
        card.setOnFocusChangeListener((view, focused) -> {
            setCardAppearance(card, colors, radius, stroke, focused);
            card.setScaleX(focused ? 1.016f : 1f);
            card.setScaleY(focused ? 1.016f : 1f);
            card.setElevation(focused ? dp(12) : dp(2));
        });
        card.setOnClickListener(view -> onClick.run());
        return card;
    }

    private void setCardAppearance(View card, int[] colors, int radius, int stroke,
                                   boolean focused) {
        GradientDrawable drawable = new GradientDrawable(
                GradientDrawable.Orientation.TL_BR, colors);
        drawable.setCornerRadius(dp(radius));
        drawable.setStroke(dp(focused ? stroke : 1),
                focused ? BLUE_FOCUS : 0xff33435b);
        card.setBackground(drawable);
    }

    private void addSmallTile(LinearLayout parent, View card) {
        LinearLayout.LayoutParams lp = new LinearLayout.LayoutParams(0, dp(110), 1f);
        lp.setMargins(dp(7), 0, dp(7), 0);
        parent.addView(card, lp);
    }

    private void openApp(String title, String... packageNames) {
        PackageManager manager = getPackageManager();
        for (String packageName : packageNames) {
            Intent intent = manager.getLeanbackLaunchIntentForPackage(packageName);
            if (intent == null) {
                intent = manager.getLaunchIntentForPackage(packageName);
            }
            if (intent != null && startIntent(intent)) {
                return;
            }
        }
        Toast.makeText(this, title + " indisponível ou sem atividade de inicialização.",
                Toast.LENGTH_LONG).show();
    }

    private boolean startIntent(Intent intent) {
        try {
            intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK
                    | Intent.FLAG_ACTIVITY_RESET_TASK_IF_NEEDED);
            startActivity(intent);
            return true;
        } catch (ActivityNotFoundException | SecurityException ex) {
            return false;
        }
    }

    private void openPrimeVideo() {
        PackageManager manager = getPackageManager();
        String[] candidates = {
                "com.amazon.avod", "com.amazon.avod.thirdpartyclient",
                "com.amazon.amazonvideo.livingroom"
        };
        for (String candidate : candidates) {
            Intent intent = manager.getLeanbackLaunchIntentForPackage(candidate);
            if (intent == null) intent = manager.getLaunchIntentForPackage(candidate);
            if (intent != null && startIntent(intent)) return;
        }
        // Algumas versões do Fire OS integram Prime Video diretamente ao launcher Amazon.
        for (ApplicationInfo info : manager.getInstalledApplications(0)) {
            String label = String.valueOf(manager.getApplicationLabel(info)).toLowerCase();
            if (label.contains("prime video")) {
                Intent intent = manager.getLeanbackLaunchIntentForPackage(info.packageName);
                if (intent == null) intent = manager.getLaunchIntentForPackage(info.packageName);
                if (intent != null && startIntent(intent)) return;
            }
        }
        Toast.makeText(this,
                "Este Fire OS não expõe um atalho do Prime Video. Abra pela Home Amazon.",
                Toast.LENGTH_LONG).show();
    }

    private void openSettings() {
        PackageManager manager = getPackageManager();
        Intent intent = manager.getLeanbackLaunchIntentForPackage("com.amazon.tv.settings.v2");
        if (intent == null) intent = manager.getLaunchIntentForPackage("com.amazon.tv.settings.v2");
        if (intent != null && startIntent(intent)) return;
        if (startIntent(new Intent(Settings.ACTION_SETTINGS))) return;
        Toast.makeText(this, "Abra Configurações na Home Amazon.", Toast.LENGTH_LONG).show();
    }

    private void showApps() {
        showingApps = true;
        if (currentContent != null) root.removeView(currentContent);

        LinearLayout column = new LinearLayout(this);
        column.setOrientation(LinearLayout.VERTICAL);
        column.setPadding(dp(42), dp(30), dp(42), dp(25));
        FrameLayout.LayoutParams lp = new FrameLayout.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT,
                ViewGroup.LayoutParams.MATCH_PARENT);
        root.addView(column, lp);
        currentContent = column;

        TextView goBack = text("←  VOLTAR", 21, WHITE, Typeface.BOLD);
        goBack.setGravity(Gravity.CENTER_VERTICAL | Gravity.START);
        goBack.setFocusable(true);
        goBack.setClickable(true);
        goBack.setOnClickListener(view -> showHome());
        column.addView(goBack, new LinearLayout.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT, dp(46)));
        column.addView(text("Aplicativos instalados", 27, LIGHT_GREY, Typeface.BOLD),
                new LinearLayout.LayoutParams(
                        ViewGroup.LayoutParams.MATCH_PARENT, dp(46)));

        ScrollView scroll = new ScrollView(this);
        scroll.setFillViewport(true);
        scroll.setClipToPadding(false);
        column.addView(scroll, new LinearLayout.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT, 0, 1f));

        LinearLayout grid = new LinearLayout(this);
        grid.setOrientation(LinearLayout.VERTICAL);
        grid.setClipChildren(false);
        grid.setPadding(0, dp(12), 0, dp(12));
        scroll.addView(grid);

        List<AppEntry> entries = loadApps();
        if (entries.isEmpty()) {
            TextView empty = text("Nenhum aplicativo inicializável encontrado.",
                    20, LIGHT_GREY, Typeface.NORMAL);
            grid.addView(empty);
        } else {
            LinearLayout row = null;
            for (int index = 0; index < entries.size(); index++) {
                if (index % 4 == 0) {
                    row = new LinearLayout(this);
                    row.setClipChildren(false);
                    grid.addView(row, new LinearLayout.LayoutParams(
                            ViewGroup.LayoutParams.MATCH_PARENT, dp(93)));
                }
                AppEntry entry = entries.get(index);
                LinearLayout card = createTile(
                        new int[]{0xff20344c, 0xff0f1c2c}, 12, 2,
                        () -> openApp(entry.title, entry.packageName));
                TextView label = text(entry.title, 17, WHITE, Typeface.BOLD);
                label.setMaxLines(2);
                label.setSingleLine(false);
                card.addView(label);
                LinearLayout.LayoutParams tileLp = new LinearLayout.LayoutParams(0, dp(83), 1f);
                tileLp.setMargins(dp(5), dp(4), dp(5), dp(4));
                row.addView(card, tileLp);
            }
        }
        goBack.requestFocus();
    }

    private List<AppEntry> loadApps() {
        PackageManager manager = getPackageManager();
        List<AppEntry> result = new ArrayList<>();
        Set<String> seen = new HashSet<>();
        for (ApplicationInfo info : manager.getInstalledApplications(0)) {
            String pkg = info.packageName;
            if (pkg.equals(getPackageName()) || pkg.startsWith("com.android.")) continue;
            if (pkg.startsWith("com.amazon.") && !pkg.equals("com.amazon.firetv.youtube")) {
                continue;
            }
            if ((info.flags & ApplicationInfo.FLAG_SYSTEM) != 0
                    && !pkg.equals("com.amazon.firetv.youtube")) {
                continue;
            }
            if (manager.getLeanbackLaunchIntentForPackage(pkg) == null
                    && manager.getLaunchIntentForPackage(pkg) == null) {
                continue;
            }
            if (seen.add(pkg)) {
                String title = String.valueOf(manager.getApplicationLabel(info));
                result.add(new AppEntry(pkg, title));
            }
        }
        Collections.sort(result, Comparator.comparing(
                (AppEntry entry) -> entry.title.toLowerCase()));
        return result;
    }

    @Override
    public void onBackPressed() {
        if (showingApps) {
            showHome();
        } else {
            // Volta para a Home original Amazon; nenhum mecanismo de redirecionamento.
            super.onBackPressed();
        }
    }

    private static final class AppEntry {
        final String packageName;
        final String title;

        AppEntry(String packageName, String title) {
            this.packageName = packageName;
            this.title = title;
        }
    }

    /** Plano de fundo desenhado em Canvas; evita decodificar bitmaps pesados na RAM. */
    private static final class DarkLandscape extends View {
        private final Paint sky = new Paint();
        private final Paint farMountain = new Paint(Paint.ANTI_ALIAS_FLAG);
        private final Paint nearMountain = new Paint(Paint.ANTI_ALIAS_FLAG);
        private final Path farPath = new Path();
        private final Path nearPath = new Path();

        DarkLandscape(Activity activity) {
            super(activity);
            farMountain.setColor(0xff101e30);
            nearMountain.setColor(0xff091523);
        }

        @Override
        protected void onSizeChanged(int width, int height, int oldWidth, int oldHeight) {
            super.onSizeChanged(width, height, oldWidth, oldHeight);
            sky.setShader(new LinearGradient(0, 0, width, height,
                    new int[]{0xff050d18, 0xff102139, 0xff07111e},
                    new float[]{0f, .58f, 1f}, Shader.TileMode.CLAMP));
            farPath.reset();
            farPath.moveTo(0, height * .69f);
            farPath.lineTo(width * .12f, height * .62f);
            farPath.lineTo(width * .22f, height * .72f);
            farPath.lineTo(width * .44f, height * .80f);
            farPath.lineTo(width * .70f, height * .73f);
            farPath.lineTo(width * .90f, height * .64f);
            farPath.lineTo(width, height * .72f);
            farPath.lineTo(width, height);
            farPath.lineTo(0, height);
            farPath.close();

            nearPath.reset();
            nearPath.moveTo(0, height * .78f);
            nearPath.cubicTo(width * .30f, height * .87f,
                    width * .52f, height * .77f, width * .70f, height * .83f);
            nearPath.cubicTo(width * .82f, height * .88f,
                    width * .93f, height * .75f, width, height * .81f);
            nearPath.lineTo(width, height);
            nearPath.lineTo(0, height);
            nearPath.close();
        }

        @Override
        protected void onDraw(Canvas canvas) {
            canvas.drawRect(0, 0, getWidth(), getHeight(), sky);
            canvas.drawPath(farPath, farMountain);
            canvas.drawPath(nearPath, nearMountain);
        }
    }
}
