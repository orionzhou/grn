source("functions.R")
dirw = file.path(dird, '71_share')
tm = v3_to_v4()

#{{{ inari
fi = file.path(dirw, '11.inari.tsv')
ti = read_tsv(fi, col_names = c('gid.v3')) %>%
    left_join(tm, by=c('gid.v3'='ogid'))
ti %>% print(n=40)
tl = ti %>% mutate(gid = ifelse(is.na(gid), gid.v3, gid)) %>% select(gid)

fn = file.path(dird, 'raw/01.tf.rds')
res = readRDS(fn)

ncfg = th %>% select(nid, lgd)
tn = res %>% select(nid, tn) %>% unnest()

to = tn %>% inner_join(tl, by=c('reg.gid'='gid')) %>%
    select(nid, reg.gid,tgt.gid, pcc) %>%
    inner_join(ncfg, by='nid') %>%
    select(-nid) %>%
    mutate(lgd = factor(lgd, levels=th$lgd)) %>%
    spread(lgd, pcc) %>%
    mutate(n_network = rowSums(!is.na(.[3:49]))) %>%
    mutate(tgt.is.TF = tgt.gid %in% tl$gid) %>%
    select(reg.gid, tgt.gid, tgt.is.TF, n_network, everything()) %>%
    arrange(desc(n_network))

fo = file.path(dirw, '15.supported.tsv')
write_tsv(to, fo)
#}}}

#{{{ summarise GRN support for UfMu TFs
fi = file.path(dird, 'uniformmu', '55.ufmu.tsv')
ti1 = read_tsv(fi) %>% select(reg.gid = b.gid, note=select_reason) %>%
    distinct(reg.gid, note) %>% mutate(tf45 = F)
fi = file.path(dird, '08_y1h', 'tf45.xlsx')
ti2 = read_xlsx(fi) %>% select(reg.gid=3, note=1) %>% mutate(tf45=T) %>%
    filter(reg.gid != 'not found')
ti = ti1 %>% bind_rows(ti2)
ti %>% count(tf45)

fs = file.path(dird, 'uniformmu/21.tf.note.tsv')
ts = read_tsv(fs)
ts1 = ts %>% select(reg.gid=gid_B73, n_tgt_biomap=n.tgt, m.drc,
    n_tgt_eqtl=eQTL_n, eQTL, eQTL_fc)

#{{{ read
fv = sprintf("%s/rf.go.rds", dirr)
ev_go = readRDS(fv)
fun_ann_note = gs$fun_ann %>% distinct(ctag,grp,note)
t_gl = gcfg$gene %>% mutate(pos=(start+end)/2) %>% select(gid,chrom,pos)
#
qtags = c('li2013','liu2017','wang2018')
hs = tibble(qtag=qtags) %>%
    mutate(fi=sprintf('~/projects/genome/data2/%s/10.rds', qtag)) %>%
    mutate(data=map(fi, readRDS)) %>%
    mutate(data=map(data, 'hs')) %>%
    select(qtag, data) %>% unnest() %>%
    select(qtag,qid,qchrom,qpos,n.tgt)
hs.tgt = tibble(qtag=qtags) %>%
    mutate(fi=sprintf('~/projects/genome/data2/%s/10.rds', qtag)) %>%
    mutate(data=map(fi, readRDS)) %>%
    mutate(data=map(data, 'hs.tgt')) %>%
    select(qtag, data) %>% unnest()
#
fv = sprintf("%s/rf.50k.rds", dirr)
ev = readRDS(fv)
#}}}

fq = file.path(dird, '14_eval_sum/34.edges.tsv')
tq = read_tsv(fq)
tq %>% count(reg.gid) %>% left_join(ti, by=c('reg.gid'='tfid')) %>%
    count(!is.na(note))

tn = ev %>% select(nid, tn) %>% unnest() %>%
    count(reg.gid, tgt.gid) %>% rename(n_grn = n)
tn1 = tn %>% filter(n_grn >= 3) %>% count(reg.gid) %>% rename(n_tgt = n)

tp = ti %>% left_join(tn1, by='reg.gid') %>%
    left_join(ts1, by='reg.gid') %>%
    mutate(n_tgt_biomap = pmin(n_tgt, n_tgt_biomap))

fo = file.path(dirw, 'tf_support.tsv')
write_tsv(tp, fo, na='')
#}}}

#{{{ generate tables for download/share
require(fs)
to = crossing(opt = c("rf",'et','xgb'), size=c('1m','100k')) %>%
    mutate(fi=sprintf("%s/%s.%s.rds", dirr, opt, size)) %>%
    slice(5:6) %>%
    mutate(x = map(fi, readRDS))
#
to1 = to %>% mutate(diro = sprintf("%s/%s_%s", dirw, opt, size)) %>%
    mutate(y = map_chr(diro, dir_create)) %>%
    select(opt,size,diro,x) %>%
    unnest(x) %>%
    mutate(fo = sprintf("%s/%s.tsv", diro, nid)) %>%
    select(nid,fo, tn) %>% unnest(tn) %>%
    select(nid,fo, regulator=reg.gid, target=tgt.gid, score) %>%
    group_by(nid,fo) %>% nest() %>%
    mutate(j = map2(data, fo, write_tsv))
#}}}

#{{{ sample meta tables after merging duplicates
fc = file.path(dird, '10.dataset.xlsx')
tc = read_xlsx(fc) %>% fill(mid, study) %>%
    filter(!str_detect(nid, "_"))

diri = '/home/springer/zhoux379/projects/rnaseq/data/11_qc'
diri = '/home/springer/zhoux379/projects/rnaseq/data/raw'
read_th_m <- function(fi) readRDS(fi)$th_m
to = tc %>% select(-subid) %>%
    mutate(fi = sprintf("%s/%s/cpm.rds", diri, mid)) %>%
    mutate(x = map(fi, read_th_m)) %>%
    mutate(fo = sprintf("%s/sample_meta/%s.tsv", dirw, nid)) %>%
    mutate(y = map2(x, fo, write_tsv))

#}}}


#{{{ phenolic genes
dirw = file.path(dird, '73_phenolic')
fi = file.path(dirw, 'PhenolicGenes.xlsx')
ti = read_xlsx(fi, col_names=c('gname','gid')) %>%
    mutate(gname = str_replace(gname, 'not included', '')) %>%
    group_by(gid) %>% summarise(gname=str_c(gname,collapse=',')) %>% ungroup()
ta = read_symbol(opt='tibble')

ft = file.path(dird, '09.tf.txt')
tt = read_tsv(ft, col_names='gid')

ncfg = t_cfg %>% select(nid, lgd)
tn = res %>% select(nid, tn) %>% unnest()

fn = file.path(dirr, 'rf.100k.rds')
tn = readRDS(fn)

to = tn %>% select(nid,study,tn) %>% unnest(tn) %>%
    select(nid, study, tf.gid=reg.gid,target.gid=tgt.gid) %>%
    group_by(tf.gid,target.gid) %>%
    summarise(nSupport=n(), support=str_c(nid,collapse=',')) %>%
    ungroup() %>%
    left_join(ta, by=c('tf.gid'='gid')) %>% rename(tf=symbol) %>%
    inner_join(ti, by=c('target.gid'='gid')) %>% rename(target=gname) %>%
    select(tf.gid,target.gid, tf, target, nSupport, support)

fo = file.path(dirw, '05.phenolic.supported.tsv')
write_tsv(to, fo, na='')
#}}}

#{{{ widiv GRN predictions
tag = 'widiv942'
dirw = file.path(dird, '73_phenolic', tag)
fi = file.path(dirw, '03.rds')
ti = readRDS(fi)

to = ti$tn
diro = '/home/springer/zhoux379/projects/s3/zhoup-share/rnaseq'
tago = 'rn19i'
fo = sprintf("%s/%s/%s.grn.tsv.gz", diro, tago, tag)
write_tsv(to, fo, na='')
#}}}

