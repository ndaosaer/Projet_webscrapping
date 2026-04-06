"""
dashboard/app.py
────────────────
Dashboard Streamlit — Analyse des Critiques de Produits
Groupe 5 — ENSAE Dakar / ANSD

Lancement :
    streamlit run dashboard/app.py

Prérequis :
    pip install streamlit plotly pandas requests wordcloud matplotlib folium streamlit-folium
    L'API FastAPI doit tourner sur http://localhost:8000
"""

import requests
import pandas as pd
import plotly.express as px
import plotly.graph_objects as go
import streamlit as st
from datetime import datetime
from collections import Counter

# ── Tentative d'import des libs optionnelles ──────────────────────────────────
try:
    from wordcloud import WordCloud
    import matplotlib.pyplot as plt
    WORDCLOUD_OK = True
except ImportError:
    WORDCLOUD_OK = False

try:
    import folium
    from streamlit_folium import st_folium
    FOLIUM_OK = True
except ImportError:
    FOLIUM_OK = False

# ── Configuration ─────────────────────────────────────────────────────────────
import os
API_BASE = os.getenv("API_URL", "https://projet-webscrapping.onrender.com")

st.set_page_config(
    page_title="Review Analyzer — Dashboard",
    page_icon="📊",
    layout="wide",
    initial_sidebar_state="expanded",
)

# ── Couleurs cohérentes avec le projet ────────────────────────────────────────
COLORS = {
    "positive": "#4ade80",
    "negative": "#f87171",
    "neutral":  "#93c5fd",
    "amazon":   "#FF9900",
    "jumia_sn": "#F68B1E",
    "googlemaps":"#4285F4",
    "tripadvisor":"#00AF87",
    "primary":  "#7C3AED",
    "bg":       "#1a1040",
}

PLATFORM_LABELS = {
    "amazon":     "Amazon",
    "jumia_sn":   "Jumia SN",
    "googlemaps": "Google Maps",
    "tripadvisor":"TripAdvisor",
}

# ── Helpers API ───────────────────────────────────────────────────────────────
@st.cache_data(ttl=60)
def fetch(endpoint: str, params: dict = None):
    try:
        r = requests.get(f"{API_BASE}{endpoint}", params=params, timeout=10)
        r.raise_for_status()
        return r.json()
    except requests.exceptions.ConnectionError:
        return None
    except Exception as e:
        st.error(f"Erreur API : {e}")
        return None

def api_ok() -> bool:
    h = fetch("/health")
    return h is not None and h.get("status") == "ok"

# ── CSS personnalisé ──────────────────────────────────────────────────────────
st.markdown("""
<style>
    .metric-card {
        background: linear-gradient(135deg, rgba(124,58,237,0.15), rgba(124,58,237,0.05));
        border: 1px solid rgba(124,58,237,0.3);
        border-radius: 12px;
        padding: 16px 20px;
        text-align: center;
    }
    .metric-value {
        font-size: 2rem;
        font-weight: 700;
        color: #7C3AED;
        margin: 0;
    }
    .metric-label {
        font-size: 0.85rem;
        color: #6B7280;
        margin: 4px 0 0 0;
    }
    .section-header {
        font-size: 1.1rem;
        font-weight: 600;
        color: #1F2937;
        margin-bottom: 12px;
        padding-bottom: 6px;
        border-bottom: 2px solid #7C3AED;
    }
    .status-ok {
        color: #059669;
        font-weight: 600;
    }
    .status-error {
        color: #DC2626;
        font-weight: 600;
    }
</style>
""", unsafe_allow_html=True)

# ══════════════════════════════════════════════════════════════════════════════
# SIDEBAR
# ══════════════════════════════════════════════════════════════════════════════
with st.sidebar:
    st.image("https://via.placeholder.com/200x100/0066cc/ffffff?text=ENSAE+DAKAR", width=200),
    st.title("Review Analyzer")
    st.caption("Dashboard analytique — Groupe 5")
    st.divider()

    # Statut API
    if api_ok():
        st.markdown('<p class="status-ok">● API connectée</p>', unsafe_allow_html=True)
    else:
        st.markdown('<p class="status-error">● API hors ligne</p>', unsafe_allow_html=True)
        st.warning("Lance l'API : `uvicorn api.main:app --port 8000`")

    st.divider()

    # Filtres globaux
    st.subheader("Filtres")
    platform_filter = st.selectbox(
        "Plateforme",
        ["Toutes", "amazon", "jumia_sn", "googlemaps", "tripadvisor"],
        format_func=lambda x: "Toutes" if x == "Toutes" else PLATFORM_LABELS.get(x, x),
    )
    sentiment_filter = st.selectbox(
        "Sentiment",
        ["Tous", "positive", "negative", "neutral"],
        format_func=lambda x: {"Tous": "Tous", "positive": "Positif",
                                "negative": "Négatif", "neutral": "Neutre"}.get(x, x),
    )

    st.divider()
    st.caption(f"Dernière mise à jour : {datetime.now().strftime('%H:%M:%S')}")
    if st.button("🔄 Rafraîchir", use_container_width=True):
        st.cache_data.clear()
        st.rerun()

# ══════════════════════════════════════════════════════════════════════════════
# HEADER
# ══════════════════════════════════════════════════════════════════════════════
st.title("📊 Analyse des Critiques de Produits")
st.caption("ENSAE Dakar · ANSD · Groupe 5 · AS3 Data Science 2025–2026")
st.divider()

if not api_ok():
    st.error("L'API FastAPI n'est pas accessible. Lance-la avec : `uvicorn api.main:app --reload --port 8000`")
    st.stop()

# ── Chargement des données ────────────────────────────────────────────────────
stats_data  = fetch("/stats")
kw_params   = {}
rev_params  = {"limit": 100}
if platform_filter != "Toutes":
    kw_params["platform"]  = platform_filter
    rev_params["platform"] = platform_filter
if sentiment_filter != "Tous":
    kw_params["sentiment"]  = sentiment_filter
    rev_params["sentiment"] = sentiment_filter

kw_data     = fetch("/keywords", {**kw_params, "limit": 30})
reviews_raw = fetch("/reviews",  rev_params)
trending    = fetch("/trending",  {"limit": 20})
cat_stats   = fetch("/stats/categories")

if not stats_data:
    st.error("Impossible de charger les statistiques.")
    st.stop()

# ══════════════════════════════════════════════════════════════════════════════
# SECTION 1 — KPI GLOBAUX
# ══════════════════════════════════════════════════════════════════════════════
st.markdown('<p class="section-header">📈 Indicateurs clés</p>', unsafe_allow_html=True)

total     = stats_data.get("total_reviews", 0)
avg_r     = stats_data.get("avg_rating")
sent      = stats_data.get("sentiment", {})
pos_count = sent.get("positive", 0)
neg_count = sent.get("negative", 0)
neu_count = sent.get("neutral", 0)
total_s   = pos_count + neg_count + neu_count
pos_rate  = round(pos_count / total_s * 100, 1) if total_s > 0 else 0
plat_count= len(stats_data.get("platforms", []))

c1, c2, c3, c4, c5 = st.columns(5)
with c1:
    st.metric("Total avis", f"{total:,}", help="Nombre total d'avis analysés")
with c2:
    st.metric("Note moyenne", f"{avg_r:.1f} ★" if avg_r else "—")
with c3:
    st.metric("Taux positif", f"{pos_rate}%",
              delta=f"+{pos_count} positifs", delta_color="normal")
with c4:
    st.metric("Plateformes", plat_count)
with c5:
    st.metric("Avis analysés NLP", total_s,
              delta=f"{round(total_s/total*100)}% du total" if total > 0 else "—")

st.divider()

# ══════════════════════════════════════════════════════════════════════════════
# SECTION 2 — SENTIMENTS + PLATEFORMES
# ══════════════════════════════════════════════════════════════════════════════
st.markdown('<p class="section-header">🎭 Sentiments & Plateformes</p>', unsafe_allow_html=True)

col_sent, col_plat = st.columns(2)

# ── Camembert sentiments ──────────────────────────────────────────────────────
with col_sent:
    if total_s > 0:
        fig_sent = px.pie(
            values=[pos_count, neg_count, neu_count],
            names=["Positif", "Négatif", "Neutre"],
            color_discrete_sequence=[
                COLORS["positive"], COLORS["negative"], COLORS["neutral"]
            ],
            hole=0.45,
            title="Répartition des sentiments",
        )
        fig_sent.update_traces(
            textinfo="percent+label",
            hovertemplate="%{label}: %{value} avis (%{percent})<extra></extra>",
        )
        fig_sent.update_layout(
            showlegend=True,
            legend=dict(orientation="h", yanchor="bottom", y=-0.2),
            margin=dict(t=40, b=40),
        )
        st.plotly_chart(fig_sent, use_container_width=True)
    else:
        st.info("Aucune donnée de sentiment disponible.")

# ── Barres plateformes ────────────────────────────────────────────────────────
with col_plat:
    platforms = stats_data.get("platforms", [])
    if platforms:
        df_plat = pd.DataFrame(platforms)
        df_plat["platform_label"] = df_plat["platform"].map(
            lambda x: PLATFORM_LABELS.get(x, x)
        )
        df_plat["color"] = df_plat["platform"].map(
            lambda x: COLORS.get(x, COLORS["primary"])
        )

        fig_plat = px.bar(
            df_plat,
            x="platform_label",
            y="total_reviews",
            color="platform_label",
            color_discrete_map={
                PLATFORM_LABELS.get(p, p): COLORS.get(p, COLORS["primary"])
                for p in df_plat["platform"].unique()
            },
            text="total_reviews",
            title="Avis par plateforme",
            labels={"platform_label": "Plateforme", "total_reviews": "Nombre d'avis"},
        )
        fig_plat.update_traces(textposition="outside")
        fig_plat.update_layout(showlegend=False, margin=dict(t=40, b=20))
        st.plotly_chart(fig_plat, use_container_width=True)
    else:
        st.info("Aucune donnée de plateforme disponible.")

st.divider()

# ══════════════════════════════════════════════════════════════════════════════
# SECTION 3 — ÉVOLUTION TEMPORELLE
# ══════════════════════════════════════════════════════════════════════════════
st.markdown('<p class="section-header">📅 Évolution temporelle</p>', unsafe_allow_html=True)

if reviews_raw and reviews_raw.get("results"):
    df_rev = pd.DataFrame(reviews_raw["results"])

    if "comment_date" in df_rev.columns and df_rev["comment_date"].notna().any():
        df_rev["date_parsed"] = pd.to_datetime(df_rev["comment_date"], errors="coerce")
        df_rev = df_rev.dropna(subset=["date_parsed"])

        if not df_rev.empty:
            df_rev["month"] = df_rev["date_parsed"].dt.to_period("M").astype(str)

            # Évolution du nombre d'avis par mois
            df_monthly = (
                df_rev.groupby(["month", "sentiment"])
                .size()
                .reset_index(name="count")
            )

            if not df_monthly.empty:
                fig_time = px.bar(
                    df_monthly,
                    x="month",
                    y="count",
                    color="sentiment",
                    color_discrete_map={
                        "positive": COLORS["positive"],
                        "negative": COLORS["negative"],
                        "neutral":  COLORS["neutral"],
                    },
                    title="Évolution mensuelle des avis par sentiment",
                    labels={"month": "Mois", "count": "Nombre d'avis", "sentiment": "Sentiment"},
                    barmode="stack",
                )
                fig_time.update_layout(
                    xaxis_tickangle=-45,
                    margin=dict(t=40, b=60),
                )
                st.plotly_chart(fig_time, use_container_width=True)

            # Évolution note moyenne
            df_note = (
                df_rev[df_rev["rating"].notna()]
                .groupby("month")["rating"]
                .mean()
                .reset_index()
            )
            df_note.columns = ["month", "avg_rating"]

            if not df_note.empty:
                fig_note = px.line(
                    df_note,
                    x="month",
                    y="avg_rating",
                    title="Évolution de la note moyenne mensuelle",
                    labels={"month": "Mois", "avg_rating": "Note moyenne"},
                    markers=True,
                    color_discrete_sequence=[COLORS["primary"]],
                )
                fig_note.update_layout(
                    xaxis_tickangle=-45,
                    yaxis=dict(range=[0, 5.5]),
                    margin=dict(t=40, b=60),
                )
                fig_note.add_hline(
                    y=4.0, line_dash="dash", line_color="gray",
                    annotation_text="Seuil 4★", annotation_position="right"
                )
                st.plotly_chart(fig_note, use_container_width=True)
        else:
            st.info("Dates non parsables dans les données.")
    else:
        st.info("Pas de données de dates disponibles pour l'évolution temporelle.")
else:
    st.info("Pas d'avis disponibles pour l'évolution temporelle.")

st.divider()

# ══════════════════════════════════════════════════════════════════════════════
# SECTION 4 — TOP PRODUITS PAR CATÉGORIE
# ══════════════════════════════════════════════════════════════════════════════
st.markdown('<p class="section-header">🏆 Top produits & tendances</p>', unsafe_allow_html=True)

if trending and trending.get("trending"):
    df_trend = pd.DataFrame(trending["trending"])
    df_trend["platform_label"] = df_trend["platform"].map(
        lambda x: PLATFORM_LABELS.get(x, x)
    )

    tab1, tab2 = st.tabs(["📊 Par nombre d'avis", "⭐ Par score de réputation"])

    with tab1:
        df_top_count = df_trend.nlargest(10, "total_reviews")
        fig_top = px.bar(
            df_top_count,
            x="total_reviews",
            y="product_name",
            orientation="h",
            color="platform_label",
            color_discrete_map={
                PLATFORM_LABELS.get(p, p): COLORS.get(p, COLORS["primary"])
                for p in df_top_count["platform"].unique()
            },
            text="total_reviews",
            title="Top 10 — Produits les plus commentés",
            labels={"total_reviews": "Nombre d'avis", "product_name": "Produit"},
        )
        fig_top.update_traces(textposition="outside")
        fig_top.update_layout(
            yaxis=dict(categoryorder="total ascending"),
            showlegend=True,
            margin=dict(t=40, l=200),
        )
        st.plotly_chart(fig_top, use_container_width=True)

    with tab2:
        df_top_rep = df_trend[df_trend["reputation_score"].notna()].nlargest(10, "reputation_score")
        if not df_top_rep.empty:
            fig_rep = px.bar(
                df_top_rep,
                x="reputation_score",
                y="product_name",
                orientation="h",
                color="reputation_score",
                color_continuous_scale=["#f87171", "#fbbf24", "#4ade80"],
                text=df_top_rep["reputation_score"].apply(lambda x: f"{x:.0f}%"),
                title="Top 10 — Meilleurs scores de réputation",
                labels={"reputation_score": "Score (%)", "product_name": "Produit"},
            )
            fig_rep.update_traces(textposition="outside")
            fig_rep.update_layout(
                xaxis=dict(range=[0, 110]),
                yaxis=dict(categoryorder="total ascending"),
                coloraxis_showscale=False,
                margin=dict(t=40, l=200),
            )
            st.plotly_chart(fig_rep, use_container_width=True)
        else:
            st.info("Pas de scores de réputation disponibles.")
else:
    st.info("Pas de données trending disponibles.")

# ── Stats par catégorie ───────────────────────────────────────────────────────
if cat_stats and cat_stats.get("categories"):
    st.subheader("Statistiques par catégorie")
    cats = cat_stats["categories"]
    df_cats = pd.DataFrame([
        {
            "Catégorie": k.capitalize(),
            "Avis": v["total_reviews"],
            "Note moy.": v["avg_rating"] or 0,
            "Score réputation (%)": v["reputation_score"] or 0,
            "Positifs": v["positive"],
            "Négatifs": v["negative"],
        }
        for k, v in cats.items()
    ])
    st.dataframe(
        df_cats.style.background_gradient(
            subset=["Score réputation (%)"], cmap="RdYlGn"
        ),
        use_container_width=True,
        hide_index=True,
    )

st.divider()

# ══════════════════════════════════════════════════════════════════════════════
# SECTION 5 — NUAGE DE MOTS-CLÉS
# ══════════════════════════════════════════════════════════════════════════════
st.markdown('<p class="section-header">☁️ Mots-clés fréquents</p>', unsafe_allow_html=True)

if kw_data and kw_data.get("top"):
    keywords = kw_data["top"]
    df_kw = pd.DataFrame(keywords)

    col_wc, col_bar = st.columns([1, 1])

    with col_bar:
        fig_kw = px.bar(
            df_kw.head(15),
            x="count",
            y="keyword",
            orientation="h",
            color="count",
            color_continuous_scale=["#C4B5FD", "#7C3AED", "#4C1D95"],
            text="count",
            title="Top 15 mots-clés",
            labels={"count": "Occurrences", "keyword": "Mot-clé"},
        )
        fig_kw.update_traces(textposition="outside")
        fig_kw.update_layout(
            yaxis=dict(categoryorder="total ascending"),
            coloraxis_showscale=False,
            margin=dict(t=40, l=150),
        )
        st.plotly_chart(fig_kw, use_container_width=True)

    with col_wc:
        if WORDCLOUD_OK:
            freq = {row["keyword"]: row["count"] for _, row in df_kw.iterrows()}
            wc = WordCloud(
                width=600,
                height=400,
                background_color="white",
                colormap="RdPu",
                max_words=50,
                prefer_horizontal=0.8,
            ).generate_from_frequencies(freq)
            fig_wc, ax = plt.subplots(figsize=(6, 4))
            ax.imshow(wc, interpolation="bilinear")
            ax.axis("off")
            plt.tight_layout(pad=0)
            st.pyplot(fig_wc)
        else:
            # Fallback : scatter plot si wordcloud non installé
            fig_bubble = px.scatter(
                df_kw.head(20),
                x="keyword",
                y="count",
                size="count",
                color="count",
                color_continuous_scale=["#C4B5FD", "#7C3AED"],
                title="Fréquence des mots-clés (bubble)",
                labels={"count": "Occurrences", "keyword": "Mot-clé"},
            )
            fig_bubble.update_layout(
                xaxis_tickangle=-45,
                coloraxis_showscale=False,
            )
            st.plotly_chart(fig_bubble, use_container_width=True)
            st.caption("💡 Installe `wordcloud` pour le nuage : `pip install wordcloud`")
else:
    st.info("Pas de mots-clés disponibles avec les filtres actuels.")

st.divider()

# ══════════════════════════════════════════════════════════════════════════════
# SECTION 6 — CARTE GÉOGRAPHIQUE
# ══════════════════════════════════════════════════════════════════════════════
st.markdown('<p class="section-header">🗺️ Carte géographique — Hôtels & Restaurants Sénégal</p>',
            unsafe_allow_html=True)

# Données géolocalisées des établissements (Google Maps + TripAdvisor)
GEO_ESTABLISHMENTS = [
    {"name": "Hôtel Terrou-Bi", "type": "Hôtel", "lat": 14.7167, "lon": -17.4677,
     "city": "Dakar", "platform": "googlemaps"},
    {"name": "King Fahd Palace", "type": "Hôtel", "lat": 14.7255, "lon": -17.4925,
     "city": "Dakar", "platform": "tripadvisor"},
    {"name": "Radisson Blu Dakar", "type": "Hôtel", "lat": 14.7319, "lon": -17.4572,
     "city": "Dakar", "platform": "tripadvisor"},
    {"name": "Le Lagon 1", "type": "Restaurant", "lat": 14.6821, "lon": -17.4677,
     "city": "Dakar", "platform": "googlemaps"},
    {"name": "Chez Loutcha", "type": "Restaurant", "lat": 14.6923, "lon": -17.4401,
     "city": "Dakar", "platform": "tripadvisor"},
    {"name": "Le Souk", "type": "Restaurant", "lat": 14.7142, "lon": -17.4502,
     "city": "Dakar", "platform": "tripadvisor"},
    {"name": "Hôtel de la Résidence", "type": "Hôtel", "lat": 16.0300, "lon": -16.5000,
     "city": "Saint-Louis", "platform": "tripadvisor"},
    {"name": "La Louisiane", "type": "Hôtel", "lat": 16.0200, "lon": -16.5100,
     "city": "Saint-Louis", "platform": "booking"},
    {"name": "Saly Portudal Beach", "type": "Hôtel", "lat": 14.4500, "lon": -17.0200,
     "city": "Saly", "platform": "booking"},
    {"name": "Les Filaos", "type": "Hôtel", "lat": 14.4600, "lon": -17.0100,
     "city": "Saly", "platform": "tripadvisor"},
    {"name": "Hôtel Fleur de Lys", "type": "Hôtel", "lat": 12.5500, "lon": -16.2700,
     "city": "Ziguinchor", "platform": "booking"},
]

if FOLIUM_OK:
    m = folium.Map(
        location=[14.4974, -14.4524],
        zoom_start=7,
        tiles="CartoDB positron",
    )

    for est in GEO_ESTABLISHMENTS:
        color  = "#7C3AED" if est["type"] == "Hôtel" else "#f87171"
        icon   = "home"    if est["type"] == "Hôtel" else "cutlery"
        popup  = folium.Popup(
            f"<b>{est['name']}</b><br>"
            f"Type : {est['type']}<br>"
            f"Ville : {est['city']}<br>"
            f"Source : {PLATFORM_LABELS.get(est['platform'], est['platform'])}",
            max_width=200,
        )
        folium.Marker(
            location=[est["lat"], est["lon"]],
            popup=popup,
            tooltip=est["name"],
            icon=folium.Icon(color="purple" if est["type"] == "Hôtel" else "red",
                             icon=icon, prefix="fa"),
        ).add_to(m)

    col_map, col_leg = st.columns([3, 1])
    with col_map:
        st_folium(m, width=700, height=450)
    with col_leg:
        st.markdown("**Légende**")
        st.markdown("🟣 Hôtels")
        st.markdown("🔴 Restaurants")
        st.divider()
        df_geo = pd.DataFrame(GEO_ESTABLISHMENTS)
        city_counts = df_geo.groupby("city").size().reset_index(name="Établissements")
        st.dataframe(city_counts, hide_index=True, use_container_width=True)
        st.caption(f"{len(GEO_ESTABLISHMENTS)} établissements référencés")
else:
    # Fallback : carte scatter Plotly si folium non installé
    df_geo = pd.DataFrame(GEO_ESTABLISHMENTS)
    fig_map = px.scatter_mapbox(
        df_geo,
        lat="lat",
        lon="lon",
        color="type",
        hover_name="name",
        hover_data=["city", "platform"],
        color_discrete_map={"Hôtel": COLORS["primary"], "Restaurant": COLORS["negative"]},
        zoom=6,
        center={"lat": 14.5, "lon": -15.5},
        mapbox_style="carto-positron",
        title="Hôtels & Restaurants — Sénégal",
    )
    fig_map.update_layout(margin=dict(t=40, b=0))
    st.plotly_chart(fig_map, use_container_width=True)
    st.caption("💡 Installe `folium streamlit-folium` pour une carte interactive enrichie.")

st.divider()

# ══════════════════════════════════════════════════════════════════════════════
# SECTION 7 — CLASSEMENT DES PLATEFORMES
# ══════════════════════════════════════════════════════════════════════════════
st.markdown('<p class="section-header">🏅 Classement des plateformes</p>',
            unsafe_allow_html=True)

platforms_data = stats_data.get("platforms", [])
if platforms_data:
    df_rank = pd.DataFrame(platforms_data)
    df_rank["platform_label"] = df_rank["platform"].map(
        lambda x: PLATFORM_LABELS.get(x, x)
    )
    df_rank["taux_positif"] = df_rank.apply(
        lambda row: round(row["positive"] / row["total_reviews"] * 100, 1)
        if row["total_reviews"] > 0 else 0, axis=1
    )
    df_rank = df_rank.sort_values("total_reviews", ascending=False).reset_index(drop=True)
    df_rank.index += 1

    col_r1, col_r2 = st.columns(2)

    with col_r1:
        fig_rank = go.Figure()
        for _, row in df_rank.iterrows():
            color = COLORS.get(row["platform"], COLORS["primary"])
            fig_rank.add_trace(go.Bar(
                name=row["platform_label"],
                x=[row["platform_label"]],
                y=[row["total_reviews"]],
                marker_color=color,
                text=[row["total_reviews"]],
                textposition="outside",
            ))
        fig_rank.update_layout(
            title="Volume d'avis par plateforme",
            showlegend=False,
            margin=dict(t=40, b=20),
            yaxis_title="Nombre d'avis",
        )
        st.plotly_chart(fig_rank, use_container_width=True)

    with col_r2:
        fig_rate = px.bar(
            df_rank,
            x="platform_label",
            y="avg_rating",
            color="platform_label",
            color_discrete_map={
                PLATFORM_LABELS.get(p, p): COLORS.get(p, COLORS["primary"])
                for p in df_rank["platform"].unique()
            },
            text=df_rank["avg_rating"].apply(
                lambda x: f"{x:.1f} ★" if x else "—"
            ),
            title="Note moyenne par plateforme",
            labels={"platform_label": "Plateforme", "avg_rating": "Note moyenne"},
            range_y=[0, 5.5],
        )
        fig_rate.update_traces(textposition="outside")
        fig_rate.update_layout(showlegend=False, margin=dict(t=40, b=20))
        fig_rate.add_hline(y=4.0, line_dash="dash", line_color="gray",
                           annotation_text="Seuil 4★")
        st.plotly_chart(fig_rate, use_container_width=True)

    # Tableau récapitulatif
    st.subheader("Tableau comparatif")
    df_display = df_rank[["platform_label", "total_reviews", "avg_rating",
                           "positive", "negative", "taux_positif"]].copy()
    df_display.columns = [
        "Plateforme", "Total avis", "Note moy.", "Positifs", "Négatifs", "Taux positif (%)"
    ]
    st.dataframe(
        df_display.style.background_gradient(
            subset=["Taux positif (%)"], cmap="RdYlGn"
        ).format({
            "Note moy.": "{:.1f}",
            "Taux positif (%)": "{:.1f}%",
        }),
        use_container_width=True,
        hide_index=False,
    )

st.divider()

# ── Footer ────────────────────────────────────────────────────────────────────
st.caption(
    "Review Analyzer Dashboard · Groupe 5 ENSAE Dakar · "
    "Superviseur : M. DIACK · Données collectées via Scrapy / Selenium / APIs"
)
